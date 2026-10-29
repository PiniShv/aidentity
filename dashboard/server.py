"""Optional, loopback-only dashboard; all operations use the existing CLI."""
import argparse
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
import os
from pathlib import Path
import re
import secrets
import signal
import subprocess
import sys
import threading
from urllib.parse import urlsplit


MAX_BODY = 5 * 1024 * 1024
MAX_DOCUMENT = 4 * 1024 * 1024
MAX_OUTPUT = 4 * 1024 * 1024
ANSI = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
URL_CREDENTIALS = re.compile(r"\b([a-zA-Z][a-zA-Z0-9+.-]{0,31}://)[^\s/\"']*@")
PROXY_ARGUMENT = re.compile(r"(--proxy-server=)([^\s\"']+)")


class RequestError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def text(value, field, maximum=1024, option_value=False, allow_path=False):
    if not isinstance(value, str) or not value or len(value) > maximum:
        raise RequestError(field + " must be nonempty text within the size limit.")
    if any(ord(ch) < 32 or 127 <= ord(ch) <= 159 for ch in value):
        raise RequestError(field + " contains a control character.")
    if not option_value and value.startswith("-"):
        raise RequestError(field + " cannot begin with a dash.")
    # The CLI recognizes these tokens globally, even as an option's value.
    if value in ("-h", "--help"):
        raise RequestError(field + " cannot be a help option.")
    if not allow_path and ("/" in value or "\\" in value):
        raise RequestError(field + " cannot contain a path separator.")
    return value


def flag(payload, key):
    value = payload.get(key, False)
    if type(value) is not bool:
        raise RequestError(key + " must be true or false.")
    return value


def redact(value, hidden=()):
    value = ANSI.sub("", value)
    for secret_value in sorted(set(hidden), key=len, reverse=True):
        if secret_value:
            value = value.replace(secret_value, "[hidden]")
    value = URL_CREDENTIALS.sub(r"\1[hidden]@", value)

    def proxy(match):
        segments = []
        for segment in match[2].split(";"):
            if "@" in segment:
                prefix = ""
                if "=" in segment:
                    prefix, segment = segment.split("=", 1)
                    prefix += "="
                if "://" in segment:
                    scheme, segment = segment.split("://", 1)
                    prefix += scheme + "://"
                segment = prefix + "[hidden]@" + segment.rsplit("@", 1)[1]
            segments.append(segment)
        return match[1] + ";".join(segments)

    return PROXY_ARGUMENT.sub(proxy, value)


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
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        pass
    # A child may ignore TERM even after the CLI itself has exited.
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
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
    def __init__(self, cli, env=None, timeout=120):
        self.cli = os.path.abspath(cli)
        self.env = dict(os.environ if env is None else env)
        self.timeout = timeout
        self.csrf_token = secrets.token_urlsafe(32)
        self.lock = threading.RLock()
        self.process_lock = threading.Lock()
        self.processes = set()
        self.stopped = False

    def stop(self):
        """A terminal interrupt must also stop detached CLI operations."""
        with self.process_lock:
            self.stopped = True
            active = list(self.processes)
        for process in active:
            terminate(process)

    def run(self, argv, stdin=None):
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
                process.stdin.close()

        writer = None
        if stdin is not None:
            writer = threading.Thread(target=feed, daemon=True)
            writer.start()
        error = None
        try:
            code = process.wait(timeout=self.timeout)
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

    def state(self):
        with self.lock:
            listing = self.run(["list", "--json"])
            apps = self.run(["__complete", "apps"])
            restorable = self.run(["__complete", "restorable"])
            version = self.run(["version"])
        errors = []
        for label, result in (("Profiles", listing), ("Installed apps", apps),
                              ("Restorable profiles", restorable), ("Version", version)):
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
                        hidden.append(value.split("=", 1)[1])
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
            stdin = json.dumps(document, ensure_ascii=False, allow_nan=False).encode("utf-8")
            if len(stdin) > MAX_DOCUMENT:
                raise RequestError("The import document exceeds the 4 MB limit.", 413)
            for launcher in document.get("launchers", []) if isinstance(document.get("launchers"), list) else []:
                if isinstance(launcher, dict) and isinstance(launcher.get("env"), list):
                    hidden += [value.split("=", 1)[1] for value in launcher["env"]
                               if isinstance(value, str) and "=" in value]
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

    def action(self, payload):
        action, argv, stdin, hidden = self.command(payload)
        with self.lock:
            result = self.run(argv, stdin)
        result["action"] = action
        # The deliberate export download retains the CLI's complete recipe.
        if action != "export":
            result["stdout"] = redact(result["stdout"], hidden)
        result["stderr"] = redact(result["stderr"], hidden)
        return result


def make_server(dashboard, port=0, assets=None):
    registered = dict(assets or {})

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.0"

        def setup(self):
            super().setup()
            self.connection.settimeout(10)

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
                path = urlsplit(self.path).path
                if path == "/api/state":
                    self.check_owner()
                    self.respond(200, dashboard.state())
                elif path in registered:
                    mime = "text/html" if path == "/" else mimetypes.guess_type(path)[0] or "text/plain"
                    self.respond(200, registered[path], mime + "; charset=utf-8")
                else:
                    self.respond(404, {"ok": False, "error": "This dashboard page does not exist."})
            except RequestError as exc:
                self.respond(exc.status, {"ok": False, "error": str(exc)})
            except (BrokenPipeError, ConnectionResetError):
                pass
            except Exception:
                self.respond(500, {"ok": False, "error": "Could not read the dashboard inventory."})

        def do_POST(self):
            try:
                self.check_request(write=True)
                if urlsplit(self.path).path != "/api/action":
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
                self.respond(200, dashboard.action(payload))
            except RequestError as exc:
                self.respond(exc.status, {"ok": False, "error": str(exc)})
            except (BrokenPipeError, ConnectionResetError):
                pass
            except TimeoutError:
                self.respond(408, {"ok": False, "error": "The request body timed out."})
            except Exception:
                self.respond(500, {"ok": False, "error": "Could not complete the dashboard action."})

        def do_OPTIONS(self):
            self.respond(405, {"ok": False, "error": "Cross-origin requests are not supported."})

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    return server


def main(argv=None, assets=None):
    parser = argparse.ArgumentParser(description="Run the optional aidentity localhost dashboard.")
    parser.add_argument("cli", help="Path to the installed aidentity executable")
    parser.add_argument("--port", type=parse_port, default=0)
    parser.add_argument("--no-open", action="store_true")
    options = parser.parse_args(argv)
    if not os.path.isfile(options.cli) or not os.access(options.cli, os.X_OK):
        parser.error("the aidentity executable is not available")
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
    print("aidentity dashboard: " + url, flush=True)
    print("Keep this terminal open. Press Ctrl-C to stop the dashboard.", flush=True)
    if not options.no_open:
        try:
            subprocess.run(["open", url], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=10, check=False)
        except (OSError, subprocess.TimeoutExpired):
            print("Open the dashboard address above in your browser.", flush=True)
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        print("\nDashboard stopped.", flush=True)
    finally:
        dashboard.stop()
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
