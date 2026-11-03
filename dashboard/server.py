"""Optional, loopback-only dashboard; all operations use the existing CLI."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import fcntl
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
import os
from pathlib import Path
import re
import secrets
import shlex
import signal
import socket
import subprocess
import sys
import threading
import time
from urllib.parse import parse_qs, urlsplit


MAX_BODY = 5 * 1024 * 1024
MAX_DOCUMENT = 4 * 1024 * 1024
MAX_OUTPUT = 4 * 1024 * 1024
MIN_SECRET = 8
TERM_GRACE = 10
STATE_TTL = 2  # seconds a poll may reuse the last inventory read
BULK_COMMANDS = (["restore", "--all"], ["rebuild", "--all"], ["doctor", "--fix"], ["update"])
ANSI = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\))")
URL_CREDENTIALS = re.compile(r"\b([a-zA-Z][a-zA-Z0-9+.-]{0,31}://)[^\s/\"']*@")
PROXY_ARGUMENT = re.compile(r"(--proxy-server=)([^\s\"']+)")
PROXY_PREFIX = re.compile(r"(?:(?:https?|ftp|socks)=)?(?:[a-zA-Z][a-zA-Z0-9+.-]{0,31}://)?")
SECRET = "•••"  # what a shown command prints in place of a hidden value
BUSY = "Another action is still running. Wait for it to finish."
DOCTOR_FACT = re.compile(r"  (macOS|aidentity|bash|launcher dir|codesign|compatible apps|profiles) {2,}(.*)")
DOCTOR_MARK = re.compile(r" {0,2}([✓!✗]) (.*)")
DOCTOR_VERDICT = re.compile(r"No problems found\.|\d+ problem\(s\) found\.")
DOCTOR_LEVEL = {"✓": "ok", "!": "warn", "✗": "error"}


class RequestError(Exception):
    def __init__(self, message, status=400, field=None):
        super().__init__(message)
        self.status = status
        self.field = field  # the payload key at fault, so the form can mark that input


class Busy(RequestError):
    """Answered with 409 and "busy": true so the page can wait instead of reporting a failure."""
    def __init__(self):
        super().__init__(BUSY, 409)


def text(value, field, maximum=1024, option_value=False, allow_path=False):
    if not isinstance(value, str) or not value or len(value) > maximum:
        raise RequestError(field + " must be nonempty text within the size limit.", field=field)
    if any(ord(ch) < 32 or 127 <= ord(ch) <= 159 for ch in value):
        raise RequestError(field + " contains a control character.", field=field)
    if not option_value and value.startswith("-"):
        raise RequestError(field + " cannot begin with a dash.", field=field)
    # The CLI recognizes these tokens globally, even as an option's value.
    if value in ("-h", "--help"):
        raise RequestError(field + " cannot be a help option.", field=field)
    if not allow_path and ("/" in value or "\\" in value):
        raise RequestError(field + " cannot contain a path separator.", field=field)
    return value


def flag(payload, key):
    value = payload.get(key, False)
    if type(value) is not bool:
        raise RequestError(key + " must be true or false.", field=key)
    return value


def redact(value, hidden=(), marker="[hidden]"):
    value = ANSI.sub("", value)
    patterns = set()
    for entry in hidden:
        name, secret_value = entry.split("=", 1)
        # A short value such as LANG=de also occurs inside words, so it is hidden only after its name.
        if len(secret_value) >= MIN_SECRET:
            patterns.add((len(secret_value), re.escape(secret_value)))
        elif secret_value:
            patterns.add((len(secret_value), "(?<=" + re.escape(name + "=") + ")" + re.escape(secret_value)))
    if patterns:
        # One pass, so a shorter value cannot match inside an earlier [hidden] marker.
        value = re.sub("|".join(pattern for _, pattern in sorted(patterns, reverse=True)), marker, value)
    value = URL_CREDENTIALS.sub(lambda match: match[1] + marker + "@", value)

    def proxy(match):
        # A password may contain ; = @ and :, so everything up to the last @ is hidden.
        rules = match[2]
        if "@" not in rules:
            return match[0]
        return match[1] + rules[:PROXY_PREFIX.match(rules).end()] + marker + rules[rules.rindex("@"):]

    return PROXY_ARGUMENT.sub(proxy, value)


def shown(argv, hidden=(), stdin=None):
    """The CLI line an action runs, ready to paste, with every hidden value as •••."""
    words = ["aidentity"]
    for index, word in enumerate(argv):
        if index and argv[index - 1] == "--env" and word in hidden:
            words.append(shlex.quote(word.split("=", 1)[0] + "=") + SECRET)
        else:
            words.append(shlex.quote(redact(word, hidden, SECRET)))
    # The import document travels over stdin; only a placeholder file name is shown.
    return " ".join(words) + (" < recipe.json" if stdin is not None else "")


def doctor_report(stdout, stderr):
    """Sort redacted doctor output into findings; a line it does not know stays visible as a warning."""
    findings, section = [], None
    for line in stdout.splitlines() + [""] + stderr.splitlines():
        if line.startswith("    "):
            continue  # detail under the line above: an install hint or a --fix rebuild's output
        if not line.strip():
            section = None
        elif line in ("aidentity doctor", "Profiles"):
            section = line
        elif fact := DOCTOR_FACT.fullmatch(line):
            # System facts stay in stdout; only the one the CLI counts as a problem is a finding.
            if fact[2].startswith("NOT WRITABLE"):
                findings.append({"level": "error", "profile": None, "text": fact[1] + " " + fact[2]})
        elif mark := DOCTOR_MARK.fullmatch(line):
            if not DOCTOR_VERDICT.match(mark[2]):  # the closing tally is what summary counts
                profile = mark[2].split(" — ", 1)[0] if section == "Profiles" else None
                findings.append({"level": DOCTOR_LEVEL[mark[1]], "profile": profile, "text": mark[2]})
        else:
            findings.append({"level": "warn", "profile": None, "text": line.strip()})
    summary = {level: sum(finding["level"] == level for finding in findings) for level in ("ok", "warn", "error")}
    return {"summary": summary, "findings": findings}


def update_versions(output):
    """Versions as `update --check` states them; null when its output names none."""
    if match := re.search(r"aidentity (\S+) is up to date\.", output):
        return {"installed": match[1], "available": match[1]}
    match = (re.search(r"aidentity (\S+) is newer than the latest release \((\S+)\)", output)
             or re.search(r"(\S+) → (\S+) is available", output))
    return {"installed": match[1] if match else None, "available": match[2] if match else None}


def parse_port(value):
    try:
        port = int(value)
    except (TypeError, ValueError):
        raise argparse.ArgumentTypeError("port must be a number from 0 to 65535")
    if not 0 <= port <= 65535:
        raise argparse.ArgumentTypeError("port must be a number from 0 to 65535")
    return port


def terminate(process):
    """Give the CLI's rollback traps time to run before forcing cancellation."""
    # macOS answers PermissionError, not ProcessLookupError, for a group whose leader has exited but is not yet reaped.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        return
    try:
        process.wait(timeout=TERM_GRACE)
    except subprocess.TimeoutExpired:
        pass
    # A child may ignore TERM even after the CLI itself has exited.
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass


def same_user_peer(peer, local):
    """Verify the client-side TCP endpoint belongs to this macOS account.

    Loopback restricts the network address, but other users of this Mac can
    still connect. The reverse endpoint is owned by this server, so accepting
    its UID would accidentally authorize every local user.
    """
    if sys.platform != "darwin" or peer[0] != "127.0.0.1" or local[0] != "127.0.0.1":
        return False
    forward = "n{}:{}->{}:{}".format(peer[0], peer[1], local[0], local[1])
    try:
        result = subprocess.run(
            ["/usr/sbin/lsof", "-nP", "-a", "-iTCP:" + str(peer[1]),
             "-sTCP:ESTABLISHED", "-Fpun"],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, timeout=2, shell=False, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return False
    if result.returncode != 0 or len(result.stdout) > MAX_OUTPUT:
        return False
    uid = None
    matches = set()
    for field in result.stdout.splitlines():
        if field.startswith("p"):
            uid = None
        elif field.startswith("u"):
            value = field[1:]
            uid = int(value) if value.isascii() and value.isdecimal() else None
        elif field == forward:
            if uid is None:
                return False
            matches.add(uid)
    return matches == {os.getuid()}


class Dashboard:
    def __init__(self, cli, env=None, timeout=120, bulk_timeout=1800):
        self.cli = os.path.abspath(cli)
        self.env = dict(os.environ if env is None else env)
        self.timeout = timeout
        self.bulk_timeout = bulk_timeout
        self.csrf_token = secrets.token_urlsafe(32)
        self.lock = threading.RLock()
        self.action_lock = threading.Lock()  # one action at a time; a second one gets Busy, not a queue
        self.process_lock = threading.Lock()
        self.processes = set()
        self.stopped = False
        self.state_cache = None

    def stop(self):
        """Stopping the dashboard must also stop the CLI operations it started."""
        with self.process_lock:
            self.stopped = True
            active = list(self.processes)
        for process in active:
            terminate(process)

    def run(self, argv, stdin=None, timeout=None):
        """Bound output and kill the complete CLI process group on timeout."""
        try:
            with self.process_lock:
                if self.stopped:
                    return {"ok": False, "exit_code": None, "stdout": "", "stderr": "",
                            "error": "The dashboard is shutting down."}
                process = subprocess.Popen(
                    [self.cli] + argv, stdin=subprocess.PIPE if stdin is not None else subprocess.DEVNULL,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=self.env,
                    start_new_session=True, shell=False)
                self.processes.add(process)
        except OSError:
            return {"ok": False, "exit_code": None, "stdout": "", "stderr": "",
                    "error": "Could not start aidentity. Restart the dashboard from an installed CLI."}
        chunks = [bytearray(), bytearray()]
        overflow = threading.Event()

        def stop():
            terminate(process)

        def collect(pipe, index):
            try:
                while True:
                    piece = pipe.read(8192)
                    if not piece:
                        break
                    room = MAX_OUTPUT - len(chunks[index])
                    chunks[index].extend(piece[:room])
                    if len(piece) > room:
                        overflow.set()
                        stop()
                        break
            finally:
                pipe.close()

        readers = [
            threading.Thread(target=collect, args=(process.stdout, 0), daemon=True),
            threading.Thread(target=collect, args=(process.stderr, 1), daemon=True)]
        for reader in readers:
            reader.start()

        def feed():
            try:
                process.stdin.write(stdin)
                process.stdin.flush()
            except (BrokenPipeError, OSError):
                pass
            finally:
                try:
                    process.stdin.close()  # re-flushes the buffer, so it raises BrokenPipeError after a failed write
                except OSError:
                    pass

        writer = None
        if stdin is not None:
            writer = threading.Thread(target=feed, daemon=True)
            writer.start()
        error = None
        try:
            code = process.wait(timeout=self.timeout if timeout is None else timeout)
        except subprocess.TimeoutExpired:
            stop()
            code = process.wait()
            error = "The aidentity command timed out. Refresh the inventory before trying again."
        finally:
            with self.process_lock:
                self.processes.discard(process)
        for reader in readers:
            reader.join(timeout=2)
        if writer is not None:
            writer.join(timeout=2)
        if overflow.is_set():
            error = "The command produced too much output. Run it in the terminal for the full result."
        result = {"ok": code == 0 and error is None, "exit_code": code,
                  "stdout": chunks[0].decode("utf-8", errors="replace"),
                  "stderr": chunks[1].decode("utf-8", errors="replace")}
        if error:
            result["error"] = error
        return result

    def state(self, fresh=False):
        commands = (["list", "--json"], ["__complete", "apps"], ["__complete", "restorable"],
                    ["__complete", "orphans"], ["version"])
        # The reads are independent; the lock still keeps them and every action apart.
        # A poll can delay an action by up to ~1 s (five CLI reads); accepted so a read never sees a half-applied action.
        with self.lock:
            if not fresh and self.state_cache and time.monotonic() - self.state_cache[0] < STATE_TTL:
                return self.state_cache[1]
            with ThreadPoolExecutor(len(commands)) as pool:
                listing, apps, restorable, orphans, version = pool.map(self.run, commands)
            self.state_cache = (time.monotonic(), self.inventory(listing, apps, restorable, orphans, version))
            return self.state_cache[1]

    def inventory(self, listing, apps, restorable, orphans, version):
        errors = []
        for label, result in (("Profiles", listing), ("Installed apps", apps),
                              ("Restorable profiles", restorable), ("Unclaimed data", orphans),
                              ("Version", version)):
            if not result["ok"]:
                errors.append(label + ": " + redact(result.get("error") or result["stderr"] or
                                                     "aidentity could not read this inventory."))
        profiles = []
        if listing["ok"]:
            try:
                profiles = json.loads(listing["stdout"])
                if not isinstance(profiles, list) or any(not isinstance(p, dict) for p in profiles):
                    raise ValueError()
                for profile in profiles:
                    profile["args"] = [redact(str(arg)) for arg in profile.get("args", [])]
                    # Defense in depth if an older or modified CLI returns assignments.
                    profile["env"] = [str(entry).split("=", 1)[0] for entry in profile.get("env", [])]
            except (ValueError, TypeError):
                profiles = []
                errors.append("Profiles: aidentity returned invalid profile JSON.")
        home = self.env.get("HOME", os.path.expanduser("~"))
        return {
            "ok": True, "csrf_token": self.csrf_token,
            "version": redact(version["stdout"]).strip().removeprefix("aidentity "),
            "profiles": profiles,
            "apps": [{"name": name} for name in apps["stdout"].splitlines() if name] if apps["ok"] else [],
            "restorable": [{"name": name} for name in restorable["stdout"].splitlines() if name] if restorable["ok"] else [],
            "unclaimed": [{"name": name} for name in orphans["stdout"].splitlines() if name] if orphans["ok"] else [],
            # A failed read is not an empty list; the page must not claim "Nothing to restore" for one.
            "restorable_ok": restorable["ok"], "unclaimed_ok": orphans["ok"],
            "paths": {
                "launchers": os.path.abspath(self.env.get("AIDENTITY_APPS_DIR") or os.path.join(home, "Applications")),
                "data": os.path.abspath(self.env.get("AIDENTITY_DATA_ROOT") or os.path.join(home, "Library/Application Support/aidentity/profiles")),
            }, "errors": errors,
        }

    def command(self, payload):
        if not isinstance(payload, dict):
            raise RequestError("The request must be a JSON object.")
        action = payload.get("action")
        common_settings = {"badge", "color", "no_badge", "args", "env", "own_extensions"}
        allowed = {
            "add": {"app", "profile", "main", "seed"} | common_settings,
            "set": {"name", "clear_args", "clear_env", "shared_extensions"} | common_settings,
            "open": {"name"}, "quit": {"name"}, "rename": {"name", "new_name"},
            "remove": {"name", "purge", "confirmed"},
            "restore": {"name", "all"}, "rebuild": {"name", "all"},
            "prune": {"confirmed"}, "doctor": {"fix"}, "export": set(),
            "import": {"document", "confirmed"}, "update": {"check"},
            "help": {"command"}, "completion": {"shell"},
        }
        if not isinstance(action, str) or action not in allowed:
            raise RequestError("Unknown dashboard action.")
        if set(payload) - allowed[action] - {"action"}:
            raise RequestError("The action contains an unsupported field.")
        argv = [action]
        stdin = None
        hidden = []
        if action in {"add", "set"}:
            if action == "add":
                argv.append(text(payload.get("app"), "app", maximum=4096, allow_path=True))
                main = flag(payload, "main")
                profile = payload.get("profile", "Main" if main else None)
                argv += ["--profile", text(profile, "profile", maximum=255)]
            else:
                argv.append(text(payload.get("name"), "name", maximum=255))
            if payload.get("no_badge") is True and payload.get("badge"):
                raise RequestError("Choose a badge or no badge, not both.")
            for key in ("badge", "color"):
                if key in payload:
                    argv += ["--" + key, text(payload[key], key, maximum=64, option_value=True)]
            options = ("no_badge", "seed", "main", "own_extensions") if action == "add" else (
                "no_badge", "clear_args", "clear_env", "own_extensions", "shared_extensions")
            if flag(payload, "own_extensions") and action == "set" and flag(payload, "shared_extensions"):
                raise RequestError("Choose own or shared extensions, not both.")
            for key in options:
                if flag(payload, key):
                    argv.append("--" + key.replace("_", "-"))
            for key, option in (("args", "--arg"), ("env", "--env")):
                values = payload.get(key, [])
                if not isinstance(values, list) or len(values) > 32:
                    raise RequestError(key + " must be a list of at most 32 entries.")
                for value in values:
                    value = text(value, key, option_value=True, allow_path=True)
                    if key == "env":
                        if "=" not in value:
                            raise RequestError("Each environment setting must use NAME=value.")
                        hidden.append(value)
                    argv += [option, value]
        elif action in {"open", "quit", "rename", "remove"}:
            argv.append(text(payload.get("name"), "name", maximum=255))
            if action == "rename":
                argv.append(text(payload.get("new_name"), "new_name", maximum=255))
            if action == "remove":
                if flag(payload, "purge"):
                    argv.append("--purge")
                if not flag(payload, "confirmed"):
                    raise RequestError("Confirm removal before continuing.")
                argv[0] = "rm"
                argv.append("--yes")
        elif action in {"restore", "rebuild"}:
            if flag(payload, "all"):
                if "name" in payload:
                    raise RequestError("Choose one profile or all profiles, not both.")
                argv.append("--all")
            else:
                argv.append(text(payload.get("name"), "name", maximum=255))
        elif action == "prune":
            if not flag(payload, "confirmed"):
                raise RequestError("Confirm pruning before continuing.")
            argv.append("--yes")
        elif action == "doctor":
            if flag(payload, "fix"):
                argv.append("--fix")
        elif action == "import":
            if not flag(payload, "confirmed"):
                raise RequestError("Confirm import before continuing.")
            document = payload.get("document")
            if isinstance(document, str):
                try:
                    document = json.loads(document)
                except ValueError:
                    raise RequestError("The import document is not valid JSON.")
            if not isinstance(document, dict):
                raise RequestError("The import document must be an exported JSON object.")
            try:
                stdin = json.dumps(document, ensure_ascii=False, allow_nan=False).encode("utf-8")
            except ValueError:
                raise RequestError("The import document contains an invalid number.")
            if len(stdin) > MAX_DOCUMENT:
                raise RequestError("The import document exceeds the 4 MB limit.", 413)
            for launcher in document.get("launchers", []) if isinstance(document.get("launchers"), list) else []:
                if isinstance(launcher, dict) and isinstance(launcher.get("env"), list):
                    hidden += [value for value in launcher["env"] if isinstance(value, str) and "=" in value]
            argv += ["/dev/stdin", "--yes"]
        elif action == "update":
            if flag(payload, "check"):
                argv.append("--check")
        elif action == "help":
            if "command" in payload:
                argv.append(text(payload["command"], "command", maximum=64))
        elif action == "completion":
            shell = payload.get("shell")
            if shell not in ("bash", "zsh", "fish"):
                raise RequestError("Choose bash, zsh or fish.")
            argv.append(shell)
        return action, argv, stdin, hidden

    def preview(self, payload):
        """Validate like action and name the command it would run; never runs or waits for anything."""
        _, argv, stdin, hidden = self.command(payload)
        return {"ok": True, "command": shown(argv, hidden, stdin)}

    def action(self, payload):
        action, argv, stdin, hidden = self.command(payload)
        timeout = self.bulk_timeout if action == "import" or argv in BULK_COMMANDS else self.timeout
        if not self.action_lock.acquire(blocking=False):
            raise Busy()
        try:
            with self.lock:
                try:
                    result = self.run(argv, stdin, timeout)
                finally:
                    self.state_cache = None  # the next read must show what the action changed
        finally:
            self.action_lock.release()
        result["action"] = action
        result["command"] = shown(argv, hidden, stdin)
        if action != "export":
            result["stdout"] = redact(result["stdout"], hidden)
        elif not result["ok"]:  # a partial recipe holds env values redact cannot see; stderr and error explain it
            result["stdout"] = ""
        result["stderr"] = redact(result["stderr"], hidden)
        # doctor prints its closing tally last: only a run that shows it finished has findings to count.
        if action == "doctor" and "error" not in result:
            if DOCTOR_VERDICT.search(result["stdout"] + "\n" + result["stderr"]):
                result.update(doctor_report(result["stdout"], result["stderr"]))
            elif result["exit_code"] < 0 or result["exit_code"] > 128:
                # Killed from outside, so no line says why; a CLI error still explains itself on stderr.
                result["error"] = "Doctor stopped before it finished (exit %d). Run the check again." % result["exit_code"]
        elif argv == ["update", "--check"]:
            result.update(update_versions(result["stdout"] + "\n" + result["stderr"]))
        return result


def make_server(dashboard, port=0, assets=None):
    registered = dict(assets or {})

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.0"
        timeout = 10

        def log_message(self, format, *args):
            # Request bodies, query strings and command output may contain secrets.
            pass

        def headers_safe(self, mime, length):
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(length))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("X-Frame-Options", "DENY")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Security-Policy",
                             "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; "
                             "img-src 'self' data:; font-src 'self'; connect-src 'self'; "
                             "object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
            self.end_headers()

        def respond(self, status, data, mime="application/json; charset=utf-8"):
            if mime.startswith("application/json"):
                body = json.dumps(data, ensure_ascii=False, allow_nan=False).encode("utf-8")
            else:
                body = data.encode("utf-8") if isinstance(data, str) else data
            self.send_response(status)
            self.headers_safe(mime, len(body))
            self.wfile.write(body)

        def check_request(self, write=False):
            current_port = self.server.server_address[1]
            hosts = {"127.0.0.1:" + str(current_port), "localhost:" + str(current_port)}
            if self.headers.get("Host", "").lower() not in hosts:
                raise RequestError("The dashboard only accepts requests for its loopback address.", 403)
            origin = self.headers.get("Origin")
            if origin is not None and origin not in {"http://" + host for host in hosts}:
                raise RequestError("Requests from another origin are not allowed.", 403)
            if self.headers.get("Sec-Fetch-Site") == "cross-site":
                raise RequestError("Requests from another website are not allowed.", 403)
            if write:
                token = self.headers.get("X-AIdentity-CSRF", "")
                if not token.isascii() or not hmac.compare_digest(token, dashboard.csrf_token):
                    raise RequestError("This dashboard session has expired. Refresh the page.", 403)

        def check_owner(self):
            if not same_user_peer(self.client_address, self.connection.getsockname()):
                raise RequestError(
                    "Open this dashboard from the same macOS account that launched aidentity. "
                    "The connection's owner could not be verified.", 403)

        def do_GET(self):
            try:
                self.check_request()
                url = urlsplit(self.path)
                path = url.path
                if path == "/api/state":
                    self.check_owner()
                    self.respond(200, dashboard.state(fresh=parse_qs(url.query).get("fresh") == ["1"]))
                elif path in registered:
                    mime = "text/html" if path == "/" else mimetypes.guess_type(path)[0] or "text/plain"
                    self.respond(200, registered[path], mime + "; charset=utf-8")
                else:
                    self.respond(404, {"ok": False, "error": "This dashboard page does not exist."})
            except RequestError as exc:
                self.respond(exc.status, {"ok": False, "error": str(exc), **({"field": exc.field} if exc.field else {})})
            except (BrokenPipeError, ConnectionResetError):
                pass
            except Exception:
                self.respond(500, {"ok": False, "error": "Could not read the dashboard inventory."})

        def do_POST(self):
            try:
                self.check_request(write=True)
                path = urlsplit(self.path).path
                if path not in ("/api/action", "/api/preview"):
                    raise RequestError("This dashboard action endpoint does not exist.", 404)
                self.check_owner()
                if self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "application/json":
                    raise RequestError("Actions require application/json.", 415)
                if self.headers.get("Transfer-Encoding"):
                    raise RequestError("Transfer encoding is not supported.")
                try:
                    length = int(self.headers.get("Content-Length", ""))
                except ValueError:
                    raise RequestError("A valid Content-Length is required.")
                if length < 1:
                    raise RequestError("The request body is empty.")
                if length > MAX_BODY:
                    raise RequestError("The request body is too large.", 413)
                body = self.rfile.read(length)
                if len(body) != length:
                    raise RequestError("The request body was incomplete.")
                try:
                    payload = json.loads(body.decode("utf-8"),
                                         parse_constant=lambda value: (_ for _ in ()).throw(ValueError()))
                except (ValueError, UnicodeError):
                    raise RequestError("The request body is not valid JSON.")
                self.respond(200, dashboard.preview(payload) if path == "/api/preview" else dashboard.action(payload))
            except RequestError as exc:
                self.respond(exc.status, {"ok": False, "error": str(exc), **({"field": exc.field} if exc.field else {}),
                                          **({"busy": True} if isinstance(exc, Busy) else {})})
            except (BrokenPipeError, ConnectionResetError):
                pass
            except (TimeoutError, socket.timeout):
                self.respond(408, {"ok": False, "error": "The request body timed out."})
            except Exception:
                self.respond(500, {"ok": False, "error": "Could not complete the dashboard action."})

        def do_OPTIONS(self):
            self.respond(405, {"ok": False, "error": "Cross-origin requests are not supported."})

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    return server


def take_lock(fd):
    """True when no dashboard runs: the running one holds this lock for its whole life."""
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return False
    return True


def read_state(fd):
    try:
        state = json.loads(os.pread(fd, 4096, 0) or b"{}")
    except ValueError:
        return {}
    return state if isinstance(state, dict) else {}


def number(state, key):
    value = state.get(key)
    return value if type(value) is int and value > 0 else None  # bool and 0 would be valid ints to os.kill


def open_browser(url, no_open):
    if no_open:
        return
    try:
        subprocess.run(["open", url], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired):
        print("Open the dashboard address above in your browser.", flush=True)


def stop_running(parser, fd):
    if take_lock(fd):
        print("No dashboard is running.")
        return 0
    pid = number(read_state(fd), "pid")
    if pid is None:
        parser.exit(1, "The dashboard is still starting. Try again in a moment.\n")
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass  # it already ended; its lock goes with it
    except PermissionError:
        parser.exit(1, "Could not stop the dashboard (process %d): permission denied.\n" % pid)
    # The dashboard first gives any CLI command it started TERM_GRACE seconds to roll back.
    deadline = time.monotonic() + TERM_GRACE + 2
    while time.monotonic() < deadline:
        if take_lock(fd):
            print("Dashboard stopped.")
            return 0
        time.sleep(0.1)
    parser.exit(1, "The dashboard (process %d) did not stop. Try 'aidentity dashboard --stop' again.\n" % pid)


def main(argv=None, assets=None):
    parser = argparse.ArgumentParser(description="Run the optional aidentity localhost dashboard.")
    parser.add_argument("cli", help="Path to the installed aidentity executable")
    parser.add_argument("--port", type=parse_port, default=0)
    parser.add_argument("--no-open", action="store_true")
    parser.add_argument("--stop", action="store_true")
    parser.add_argument("--state", required=True, help="the file that names the running dashboard")
    options = parser.parse_args(argv)
    if not os.path.isfile(options.cli) or not os.access(options.cli, os.X_OK):
        parser.error("the aidentity executable is not available")
    os.makedirs(os.path.dirname(os.path.abspath(options.state)), mode=0o700, exist_ok=True)
    state = os.open(options.state, os.O_RDWR | os.O_CREAT, 0o600)
    if options.stop:
        return stop_running(parser, state)
    if not take_lock(state):
        port = number(read_state(state), "port")
        if port is None:
            parser.exit(1, "The dashboard is still starting. Try again in a moment.\n")
        url = "http://127.0.0.1:" + str(port)
        if options.port and options.port != port:
            parser.exit(1, "A dashboard is already running at %s. Run 'aidentity dashboard --stop' first "
                           "to use another port.\n" % url)
        print("aidentity dashboard: " + url + " (already running)", flush=True)
        print("Stop it with 'aidentity dashboard --stop'.", flush=True)
        open_browser(url, options.no_open)
        return 0
    os.ftruncate(state, 0)  # a stale address must not be reused while this one starts
    if assets is None:
        assets = globals().get("ASSETS")
    if assets is None:
        folder = Path(__file__).resolve().parent
        assets = {"/": (folder / "index.html").read_text(encoding="utf-8")}
        for filename in ("app.js", "styles.css", "experience.js", "experience.css"):
            if (folder / filename).is_file():
                assets["/" + filename] = (folder / filename).read_text(encoding="utf-8")
    try:
        dashboard = Dashboard(options.cli)
        server = make_server(dashboard, options.port, assets)
    except OSError:
        parser.exit(1, "The dashboard port is unavailable. Choose another --port or use --port 0.\n")
    url = "http://127.0.0.1:" + str(server.server_address[1])
    # Nothing above starts a thread, so the fork copies a whole, idle process.
    child = os.fork()
    if child:
        # Never unlock here: the child shares this lock, and an unlock would release it for both.
        os.pwrite(state, json.dumps({"pid": child, "port": server.server_address[1]}).encode(), 0)
        print("aidentity dashboard: " + url, flush=True)
        print("Running in the background. Stop it with 'aidentity dashboard --stop'.", flush=True)
        open_browser(url, options.no_open)
        return 0
    try:
        # Its own session and no terminal or pipe: a closed terminal or `| cat` neither ends nor waits for it.
        os.setsid()
        devnull = os.open(os.devnull, os.O_RDWR)
        for fd in (0, 1, 2):
            os.dup2(devnull, fd)
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        signal.signal(signal.SIGTERM, signal.default_int_handler)  # --stop runs the cleanup below
        try:
            server.serve_forever(poll_interval=0.25)
        except KeyboardInterrupt:
            pass
        finally:
            dashboard.stop()
            server.server_close()
    finally:
        os._exit(0)  # the child never returns into the caller of main()


if __name__ == "__main__":
    sys.exit(main())
