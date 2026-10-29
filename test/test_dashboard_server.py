"""Dashboard API tests use an isolated fake executable, never the user's apps."""
import http.client
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

SERVER_PATH = Path(__file__).resolve().parents[1] / "dashboard" / "server.py"


@unittest.skipUnless(sys.platform == "darwin", "The dashboard uses macOS TCP connection ownership.")
class DashboardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("dashboard_server", SERVER_PATH)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.log = self.root / "calls.jsonl"
        cli = self.root / "aidentity"
        cli.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys, time\n"
            "a=sys.argv[1:]\n"
            "with open(os.environ['DASHBOARD_TEST_LOG'],'a') as f: f.write(json.dumps(a)+'\\n')\n"
            "d=os.path.join(os.environ['HOME'],'delay')\n"
            "if os.path.exists(d): time.sleep(float(open(d).read()))\n"
            "if a == ['list','--json']:\n"
            " print(json.dumps([{'name':'Claude Work','app':'Claude','app_path':'/Apps/Claude.app',"
            "'profile':'Work','data_dir':'/Data/claude-work','main':False,'status':'running',"
            "'badge':'W','color':'aabbcc','built_by':'1.6.1',"
            "'args':['--proxy-server=https://alice:private@proxy.example:8080'],"
            "'env':['HTTPS_PROXY'], 'own_extensions':False}]))\n"
            "elif a == ['__complete','apps']: print('Claude\\nVisual Studio Code')\n"
            "elif a == ['__complete','restorable']: print('Claude Personal')\n"
            "elif a == ['version']: print('aidentity 1.6.1')\n"
            "elif a and a[0] == 'import':\n"
            " d=json.load(sys.stdin); print(json.dumps({'imported':len(d['launchers'])}))\n"
            "elif a and a[0] == 'export':\n"
            " print(json.dumps({'aidentity_export':1,'exported_by':'1.6.1','launchers':[]}))\n"
            "elif a == ['doctor','--fix']:\n"
            " print('Cannot repair this fixture',file=sys.stderr); sys.exit(2)\n"
            "elif a == ['help','slow']: time.sleep(5)\n"
            "elif a in (['help','cleanup'],['help','slowcleanup']):\n"
            " import signal\n"
            " def cleanup(sig, frame):\n"
            "  time.sleep(1.5 if a[1] == 'slowcleanup' else 0)\n"
            "  with open(os.environ['DASHBOARD_TEST_CLEANUP'],'w') as f: f.write('cleaned')\n"
            "  sys.exit(143)\n"
            " signal.signal(signal.SIGTERM,cleanup); time.sleep(5)\n"
            "elif a == ['help','flood']: print('x' * (5 * 1024 * 1024))\n"
            "else: print(json.dumps(a))\n",
            encoding="utf-8",
        )
        cli.chmod(0o700)
        env = dict(os.environ)
        env.update(
            HOME=str(self.root),
            PYTHONDONTWRITEBYTECODE="1",
            DASHBOARD_TEST_LOG=str(self.log),
            DASHBOARD_TEST_CLEANUP=str(self.root / "cleaned"),
            AIDENTITY_APPS_DIR=str(self.root / "Launchers"),
            AIDENTITY_DATA_ROOT=str(self.root / "Data"),
            AIDENTITY_APP_DIRS=str(self.root / "Installed"),
        )
        self.backend = self.module.Dashboard(str(cli), env=env, timeout=0.5)
        self.server = self.module.make_server(
            self.backend, port=0,
            assets={"/": "<!doctype html><title>Accounts</title>",
                    "/experience.js": "console.log('experience');"},
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.port = self.server.server_address[1]
        self.origin = "http://127.0.0.1:" + str(self.port)
        self.token = self.backend.csrf_token

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.tmp.cleanup()

    def request(self, method, path, payload=None, headers=None, raw=None):
        body = raw if raw is not None else (
            json.dumps(payload).encode() if payload is not None else None)
        supplied = {"Content-Type": "application/json", "Origin": self.origin,
                    "X-AIdentity-CSRF": self.token}
        supplied.update(headers or {})
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=4)
        connection.request(method, path, body=body, headers=supplied)
        response = connection.getresponse()
        data = response.read()
        result = (response.status, dict(response.getheaders()),
                  json.loads(data) if response.getheader("Content-Type", "").startswith(
                      "application/json") else data.decode())
        connection.close()
        return result

    def action(self, payload, **kwargs):
        return self.request("POST", "/api/action", payload, **kwargs)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_state_uses_cli_inventory_and_hides_proxy_credentials(self):
        status, headers, state = self.request("GET", "/api/state")
        self.assertEqual(status, 200)
        self.assertTrue(state["ok"])
        self.assertEqual(state["version"], "1.6.1")
        self.assertEqual(state["apps"], [{"name": "Claude"}, {"name": "Visual Studio Code"}])
        self.assertEqual(state["restorable"], [{"name": "Claude Personal"}])
        self.assertEqual(state["profiles"][0]["env"], ["HTTPS_PROXY"])
        self.assertNotIn("private", json.dumps(state))
        self.assertEqual(state["csrf_token"], self.token)
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertNotIn("Access-Control-Allow-Origin", headers)

    def test_shell_metacharacters_are_passed_as_one_argument(self):
        name = "Claude Work; touch " + str(self.root / "unwanted")
        status, _, result = self.action({"action": "open", "name": name.replace("/", "_")})
        self.assertEqual(status, 200)
        self.assertTrue(result["ok"])
        self.assertEqual(self.calls(), [["open", name.replace("/", "_")]])
        self.assertFalse((self.root / "unwanted").exists())

    def test_full_add_options_map_to_cli_and_env_values_are_redacted(self):
        status, _, result = self.action({
            "action": "add", "app": "Claude", "profile": "Work", "badge": "W",
            "color": "blue", "seed": True, "args": ["--lang=de"],
            "env": ["HTTPS_PROXY=https://alice:private@proxy.example"],
            "own_extensions": True,
        })
        self.assertEqual(status, 200)
        self.assertTrue(result["ok"])
        self.assertEqual(self.calls()[0], [
            "add", "Claude", "--profile", "Work", "--badge", "W", "--color", "blue",
            "--seed", "--own-extensions", "--arg", "--lang=de",
            "--env", "HTTPS_PROXY=https://alice:private@proxy.example"])
        self.assertNotIn("private", result["stdout"])

    def test_short_env_values_do_not_corrupt_output(self):
        status, _, result = self.action({
            "action": "add", "app": "Claude", "profile": "Work",
            "env": ["LANG=de", "LC_ALL=C", "TZ=UTC", "API_TOKEN=hunter2", "PROXY_TOKEN=s3cr3t-value"]})
        self.assertEqual(status, 200)
        argv = json.loads(result["stdout"])
        self.assertEqual(argv[:4], ["add", "Claude", "--profile", "Work"])
        self.assertEqual(argv[5::2], ["LANG=[hidden]", "LC_ALL=[hidden]", "TZ=[hidden]",
                                      "API_TOKEN=[hidden]", "PROXY_TOKEN=[hidden]"])
        self.assertEqual(self.module.redact("Created launcher Claude Work", ["LANG=de"]),
                         "Created launcher Claude Work")
        self.assertEqual(self.module.redact("token s3cr3t-value", ["PROXY_TOKEN=s3cr3t-value"]),
                         "token [hidden]")

    def test_set_only_sends_requested_settings(self):
        _, _, result = self.action({
            "action": "set", "name": "Claude Work", "clear_args": True,
            "args": ["--lang=fr"], "shared_extensions": True})
        self.assertTrue(result["ok"])
        self.assertEqual(self.calls()[0], [
            "set", "Claude Work", "--clear-args", "--shared-extensions", "--arg", "--lang=fr"])

    def test_destructive_commands_require_explicit_confirmation(self):
        for payload in (
            {"action": "remove", "name": "Claude Work", "purge": True},
            {"action": "prune"}, {"action": "import", "document": {}}):
            with self.subTest(payload=payload):
                status, _, result = self.action(payload)
                self.assertEqual(status, 400)
                self.assertFalse(result["ok"])
        self.assertEqual(self.calls(), [])

    def test_confirmed_removal_and_pruning_use_yes(self):
        self.action({"action": "remove", "name": "Claude Work", "purge": True, "confirmed": True})
        self.action({"action": "prune", "confirmed": True})
        self.assertEqual(self.calls(), [["rm", "Claude Work", "--purge", "--yes"], ["prune", "--yes"]])

    def test_remaining_commands_preserve_cli_parity(self):
        pairs = [
            ({"action": "quit", "name": "Claude Work"}, ["quit", "Claude Work"]),
            ({"action": "rename", "name": "Claude Work", "new_name": "Client"}, ["rename", "Claude Work", "Client"]),
            ({"action": "restore", "all": True}, ["restore", "--all"]),
            ({"action": "restore", "name": "Claude Personal"}, ["restore", "Claude Personal"]),
            ({"action": "rebuild", "all": True}, ["rebuild", "--all"]),
            ({"action": "rebuild", "name": "Claude Work"}, ["rebuild", "Claude Work"]),
            ({"action": "doctor"}, ["doctor"]),
            ({"action": "update", "check": True}, ["update", "--check"]),
            ({"action": "update"}, ["update"]),
            ({"action": "help", "command": "add"}, ["help", "add"]),
            ({"action": "help"}, ["help"]),
            ({"action": "completion", "shell": "fish"}, ["completion", "fish"]),
        ]
        for payload, _ in pairs:
            with self.subTest(payload=payload):
                status, _, result = self.action(payload)
                self.assertEqual(status, 200)
                self.assertTrue(result["ok"])
        self.assertEqual(self.calls(), [expected for _, expected in pairs])

    def test_import_receives_document_over_stdin_without_backend_files(self):
        document = {"aidentity_export": 1, "exported_by": "1.6.1", "launchers": []}
        before = set(self.root.iterdir())
        status, _, result = self.action({"action": "import", "document": document, "confirmed": True})
        self.assertEqual(status, 200)
        self.assertTrue(result["ok"])
        self.assertEqual(json.loads(result["stdout"]), {"imported": 0})
        self.assertEqual(self.calls(), [["import", "/dev/stdin", "--yes"]])
        self.assertEqual(set(self.root.iterdir()) - before, {self.log})

    def test_import_rejects_out_of_range_numbers(self):
        for raw in (
            b'{"action":"import","confirmed":true,"document":{"launchers":[],"n":1e999}}',
            json.dumps({"action": "import", "confirmed": True,
                        "document": '{"launchers":[],"n":NaN}'}).encode(),
        ):
            with self.subTest(raw=raw):
                status, _, result = self.request("POST", "/api/action", raw=raw)
                self.assertEqual(status, 400)
                self.assertEqual(result["error"], "The import document contains an invalid number.")
        self.assertEqual(self.calls(), [])

    def test_export_is_valid_recipe_output(self):
        _, _, result = self.action({"action": "export"})
        self.assertEqual(json.loads(result["stdout"])["aidentity_export"], 1)

    def test_cli_errors_preserve_exit_status_and_explanation(self):
        status, _, result = self.action({"action": "doctor", "fix": True})
        self.assertEqual(status, 200)
        self.assertFalse(result["ok"])
        self.assertEqual(result["exit_code"], 2)
        self.assertIn("Cannot repair", result["stderr"])

    def test_timeout_returns_error_and_stops_cli(self):
        started = time.monotonic()
        _, _, result = self.action({"action": "help", "command": "slow"})
        self.assertFalse(result["ok"])
        self.assertIn("timed out", result["error"])
        self.assertLess(time.monotonic() - started, 3)

    def test_schemeless_proxy_credentials_are_hidden(self):
        _, _, result = self.action({
            "action": "set", "name": "Claude Work",
            "args": ["--proxy-server=alice:private@proxy.example:8080"]})
        self.assertTrue(result["ok"])
        self.assertNotIn("alice:private", result["stdout"])
        self.assertIn("proxy.example:8080", result["stdout"])

    def test_proxy_passwords_with_separators_are_hidden(self):
        cases = {
            "--proxy-server=user:p=ss@host:1080": "--proxy-server=[hidden]@host:1080",
            "--proxy-server=user:pa;ss@host:1080": "--proxy-server=[hidden]@host:1080",
            "--proxy-server=user:pa@ss@host:1080": "--proxy-server=[hidden]@host:1080",
            "--proxy-server=user:pa:ss@host:1080": "--proxy-server=[hidden]@host:1080",
            "--proxy-server=https=user:p;a=s@s:s@host:443": "--proxy-server=https=[hidden]@host:443",
            "--proxy-server=socks5://user:pa/ss@host:1080": "--proxy-server=socks5://[hidden]@host:1080",
            "--proxy-server=http=ann:one@a:80;https=bob:two@b:443": "--proxy-server=http=[hidden]@b:443",
        }
        for value, expected in cases.items():
            with self.subTest(value=value):
                self.assertEqual(self.module.redact(value), expected)

    def test_terminal_escape_stripping_is_linear(self):
        self.assertEqual(self.module.redact(
            "\x1b[31mred\x1b[0m \x1b]8;;https://x\x1b\\link\x1b]8;;\x07"), "red link")
        started = time.monotonic()
        self.module.redact("\x1b]" * 50000)
        self.assertLess(time.monotonic() - started, 1)

    def test_state_reads_inventory_concurrently(self):
        self.backend.timeout = 5
        (self.root / "delay").write_text("0.5")
        started = time.monotonic()
        state = self.backend.state()
        self.assertLess(time.monotonic() - started, 1.5)
        self.assertEqual(state["errors"], [])
        self.assertEqual(state["version"], "1.6.1")

    def test_output_limit_reports_failure(self):
        _, _, result = self.action({"action": "help", "command": "flood"})
        self.assertFalse(result["ok"])
        self.assertIn("too much output", result["error"])
        self.assertLessEqual(len(result["stdout"]), 4 * 1024 * 1024)

    def test_stopping_dashboard_kills_active_cli(self):
        self.backend.timeout = 5
        results = []
        thread = threading.Thread(target=lambda: results.append(
            self.backend.action({"action": "help", "command": "slow"})))
        thread.start()
        deadline = time.monotonic() + 2
        while not self.calls() and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue(self.calls(), "The CLI fixture did not start.")
        self.backend.stop()
        thread.join(timeout=2)
        self.assertFalse(thread.is_alive())
        self.assertFalse(results[0]["ok"])

    def test_timeout_allows_cli_rollback_trap_to_run(self):
        _, _, result = self.action({"action": "help", "command": "cleanup"})
        self.assertFalse(result["ok"])
        self.assertIn("timed out", result["error"])
        self.assertTrue((self.root / "cleaned").exists(), "The CLI cleanup trap never ran.")

    def test_timeout_gives_slow_rollback_trap_time_to_finish(self):
        _, _, result = self.action({"action": "help", "command": "slowcleanup"})
        self.assertIn("timed out", result["error"])
        self.assertTrue((self.root / "cleaned").exists(), "The CLI cleanup trap was killed.")

    def test_bulk_actions_use_the_long_timeout(self):
        self.backend.timeout = 0.1
        self.backend.bulk_timeout = 5
        (self.root / "delay").write_text("0.3")
        for payload in (
            {"action": "restore", "all": True}, {"action": "rebuild", "all": True},
            {"action": "doctor", "fix": True}, {"action": "update"},
            {"action": "import", "document": {"launchers": []}, "confirmed": True},
        ):
            with self.subTest(payload=payload):
                _, _, result = self.action(payload)
                self.assertNotIn("error", result)
        _, _, result = self.action({"action": "update", "check": True})
        self.assertIn("timed out", result["error"])

    def test_incomplete_body_times_out_with_408(self):
        self.server.RequestHandlerClass.timeout = 0.3
        status, _, result = self.request("POST", "/api/action", raw=b'{"action":"help"}',
                                         headers={"Content-Length": "100"})
        self.assertEqual(status, 408)
        self.assertFalse(result["ok"])

    def test_foreign_host_origin_and_fetch_site_cannot_run_actions(self):
        for headers in (
            {"Host": "evil.example:" + str(self.port)},
            {"Origin": "https://evil.example"},
            {"Origin": "null"},
            {"Sec-Fetch-Site": "cross-site"},
            {"X-AIdentity-CSRF": "wrong"},
            {"X-AIdentity-CSRF": "é"},
        ):
            with self.subTest(headers=headers):
                status, _, result = self.action({"action": "open", "name": "Claude Work"}, headers=headers)
                self.assertEqual(status, 403)
                self.assertFalse(result["ok"])
        self.assertEqual(self.calls(), [])

    def test_foreign_origin_cannot_read_session_token(self):
        status, _, _ = self.request("GET", "/api/state", headers={"Origin": "https://evil.example"})
        self.assertEqual(status, 403)
        self.assertEqual(self.calls(), [])

    def test_foreign_os_account_cannot_read_token_or_run_commands(self):
        with mock.patch.object(self.module, "same_user_peer", return_value=False):
            status, _, result = self.request("GET", "/api/state")
            self.assertEqual(status, 403)
            self.assertFalse(result["ok"])
            self.assertNotIn("csrf_token", result)
            self.assertIn("same macOS account", result["error"])
            status, _, result = self.action({"action": "open", "name": "Claude Work"})
            self.assertEqual(status, 403)
            self.assertFalse(result["ok"])
            status, _, _ = self.request("GET", "/")
            self.assertEqual(status, 200)
        self.assertEqual(self.calls(), [])

    def test_peer_check_matches_only_exact_forward_connection_and_owner(self):
        cases = [
            ("p101\nu501\nn127.0.0.1:49152->127.0.0.1:8173\n", True),
            ("p101\nu502\nn127.0.0.1:49152->127.0.0.1:8173\n"
             "p102\nu501\nn127.0.0.1:8173->127.0.0.1:49152\n", False),
            ("p102\nu501\nn127.0.0.1:8173->127.0.0.1:49152\n", False),
            ("p101\nu501\nn127.0.0.1:49153->127.0.0.1:8173\n", False),
            ("p101\nu501\nn127.0.0.1:49152->127.0.0.1:8174\n", False),
            ("p101\nu501\np102\nn127.0.0.1:49152->127.0.0.1:8173\n", False),
            ("p101\nu501\nn127.0.0.1:49152->127.0.0.1:8173\n"
             "p102\nu502\nn127.0.0.1:49152->127.0.0.1:8173\n", False),
        ]
        for output, expected in cases:
            with self.subTest(output=output):
                result = subprocess.CompletedProcess([], 0, stdout=output, stderr="")
                with mock.patch.object(self.module.subprocess, "run", return_value=result) as run:
                    with mock.patch.object(self.module.os, "getuid", return_value=501):
                        self.assertEqual(self.module.same_user_peer(
                            ("127.0.0.1", 49152), ("127.0.0.1", 8173)), expected)
                self.assertEqual(run.call_args.args[0], [
                    "/usr/sbin/lsof", "-nP", "-a", "-iTCP:49152",
                    "-sTCP:ESTABLISHED", "-Fpun"])
                self.assertEqual(run.call_args.kwargs["timeout"], 2)
                self.assertFalse(run.call_args.kwargs.get("shell", False))

    def test_peer_check_fails_closed_when_native_lookup_fails(self):
        for failure in (
            FileNotFoundError(), PermissionError(),
            subprocess.TimeoutExpired(["/usr/sbin/lsof"], 2),
        ):
            with self.subTest(failure=type(failure).__name__):
                with mock.patch.object(self.module.subprocess, "run", side_effect=failure):
                    self.assertFalse(self.module.same_user_peer(
                        ("127.0.0.1", 49152), ("127.0.0.1", 8173)))
        result = subprocess.CompletedProcess([], 1,
            stdout="p101\nu501\nn127.0.0.1:49152->127.0.0.1:8173\n", stderr="")
        with mock.patch.object(self.module.subprocess, "run", return_value=result):
            self.assertFalse(self.module.same_user_peer(
                ("127.0.0.1", 49152), ("127.0.0.1", 8173)))

    def test_loopback_page_navigation_without_origin_works(self):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=4)
        connection.request("GET", "/")
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        self.assertIn(b"Accounts", response.read())
        connection.close()

    def test_unknown_fields_option_injection_and_wrong_types_are_rejected(self):
        invalid = [
            {"action": "exec", "command": "touch sentinel"},
            {"action": "open", "name": "../other"},
            {"action": "open", "name": "--help"},
            {"action": "open", "name": "Claude\nWork"},
            {"action": "open", "name": "Claude Work", "argv": ["--purge"]},
            {"action": "add", "app": "Claude", "profile": "Work", "main": "false"},
            {"action": "set", "name": "Claude Work", "args": "--lang=de"},
            {"action": "set", "name": "Claude Work", "badge": "--help"},
            {"action": "set", "name": "Claude Work", "color": "-h"},
            {"action": "set", "name": "Claude Work", "args": ["--help"]},
            {"action": "completion", "shell": "bash; touch sentinel"},
            {"action": "restore", "all": True, "name": "Claude Work"},
            {"action": "prune", "confirmed": 1},
        ]
        for payload in invalid:
            with self.subTest(payload=payload):
                status, _, result = self.action(payload)
                self.assertEqual(status, 400)
                self.assertFalse(result["ok"])
        self.assertEqual(self.calls(), [])

    def test_malformed_body_and_non_json_content_type_are_rejected(self):
        for body, headers, expected in [
            (b"{bad", {}, 400),
            (b"[]", {}, 400),
            (b"{}", {"Content-Type": "text/plain"}, 415),
            (b"{}", {"Content-Length": str(6 * 1024 * 1024)}, 413),
        ]:
            with self.subTest(body=body, headers=headers):
                status, _, result = self.request("POST", "/api/action", raw=body, headers=headers)
                self.assertEqual(status, expected)
                self.assertFalse(result["ok"])
        self.assertEqual(self.calls(), [])

    def test_serves_only_registered_assets_with_security_headers(self):
        status, headers, content = self.request("GET", "/experience.js")
        self.assertEqual(status, 200)
        self.assertIn("experience", content)
        self.assertEqual(headers["X-Content-Type-Options"], "nosniff")
        self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])
        for path in ("/../server.py", "/server.py", "/api/action"):
            status, _, _ = self.request("GET", path)
            self.assertEqual(status, 404)

    def test_port_parser_rejects_out_of_range_and_non_numeric(self):
        self.assertEqual(self.module.parse_port("0"), 0)
        self.assertEqual(self.module.parse_port("8173"), 8173)
        for value in ("-1", "65536", "abc"):
            with self.subTest(value=value):
                with self.assertRaises(Exception):
                    self.module.parse_port(value)


if __name__ == "__main__":
    unittest.main()
