"""Verify an installed dashboard works without its source checkout."""

import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import tempfile
import threading
import unittest
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.uname().sysname == "Darwin", "aidentity requires macOS")
class InstalledDashboardTests(unittest.TestCase):
    def test_copied_cli_serves_all_assets_and_isolated_state(self):
        with tempfile.TemporaryDirectory(prefix="aidentity-dashboard-installed-") as temp:
            folder = Path(temp)
            binary = folder / "aidentity"
            shutil.copy2(ROOT / "bin" / "aidentity", binary)
            for name in ("home", "launchers", "profiles", "source-apps"):
                (folder / name).mkdir()
            (folder / "json.py").write_text(
                'raise RuntimeError("Untrusted current-directory module was imported")\n'
            )
            env = dict(os.environ, HOME=str(folder / "home"),
                       AIDENTITY_APPS_DIR=str(folder / "launchers"),
                       AIDENTITY_DATA_ROOT=str(folder / "profiles"),
                       AIDENTITY_APP_DIRS=str(folder / "source-apps"),
                       PYTHONPATH=str(folder))
            child = subprocess.Popen(
                [str(binary), "dashboard", "--no-open"], cwd=folder, env=env,
                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, start_new_session=True,
            )
            lines = queue.Queue()

            def read_lines():
                for line in child.stdout:
                    lines.put(line)
                lines.put(None)

            reader = threading.Thread(target=read_lines, daemon=True)
            reader.start()
            try:
                address = None
                while address is None:
                    line = lines.get(timeout=15)
                    self.assertIsNotNone(line, "dashboard exited before opening a port")
                    match = re.search(r"http://127\.0\.0\.1:\d+", line)
                    if match:
                        address = match.group(0)
                for path, marker in (
                    ("/", b"aidentity"), ("/app.js", b"api/state"),
                    ("/styles.css", b"{"), ("/experience.js", b"AidentityExperience"),
                    ("/experience.css", b"xp-keys"),
                ):
                    with urlopen(address + path, timeout=10) as response:
                        self.assertEqual(response.status, 200)
                        self.assertIn(marker, response.read())
                with urlopen(address + "/api/state", timeout=20) as response:
                    state = json.load(response)
                self.assertTrue(state["ok"])
                self.assertEqual(state["profiles"], [])
                self.assertEqual(state["apps"], [])
                self.assertTrue(state["csrf_token"])
                self.assertEqual(list((folder / "launchers").iterdir()), [])
                self.assertEqual(list((folder / "profiles").iterdir()), [])
            finally:
                # Stop only the process group this test created.
                import signal
                if child.poll() is None:
                    os.killpg(child.pid, signal.SIGINT)
                try:
                    child.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait(timeout=5)
                child.stdout.close()
                reader.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
