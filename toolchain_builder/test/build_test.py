# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import errno
import fcntl
import os
from pathlib import Path
import pty
import signal
import subprocess
import sys
import tempfile
import termios
import time
import unittest


BUILD = Path(__file__).resolve().parents[1] / "build.sh"
FAKE_ELIXIR = """#!/usr/bin/env python3
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

root = Path(os.environ["BUILD_TEST_DIR"])
role = sys.argv[1] if sys.argv[1].startswith("--") else "elixir"
if role == "--compiler":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
else:
    child = "--compiler" if role == "--make" else "--make"
    subprocess.Popen([sys.executable, __file__, child],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
(root / (role + ".pid")).write_text(str(os.getpid()))
while not (root / "--compiler.pid").exists():
    time.sleep(0.01)
if role == "elixir" and os.environ["BUILD_TEST_MODE"] == "failure":
    sys.exit(23)
while True:
    time.sleep(1)
"""


def controlling_terminal():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)


def running(pid):
    result = subprocess.run(
        ["ps", "-p", str(pid), "-o", "stat="], capture_output=True, text=True
    )
    return result.returncode == 0 and not result.stdout.lstrip().startswith("Z")


class BuildProcessTest(unittest.TestCase):
    def run_build(self, mode, interrupt=None):
        with tempfile.TemporaryDirectory(prefix="toolchain-interrupt-") as directory:
            root = Path(directory)
            fake = root / "elixir"
            fake.write_text(FAKE_ELIXIR)
            fake.chmod(0o755)
            env = dict(
                os.environ,
                PATH=f"{root}{os.pathsep}{os.environ['PATH']}",
                BUILD_TEST_DIR=directory,
                BUILD_TEST_MODE=mode,
            )
            master, slave = pty.openpty()
            pids = []
            unrelated = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
            with (root / "output").open("w+") as output:
                build = subprocess.Popen(
                    ["bash", str(BUILD), "armv7-nerves-linux-gnueabihf--gcc15"],
                    stdin=slave,
                    stdout=output,
                    stderr=output,
                    env=env,
                    preexec_fn=controlling_terminal,
                )
                os.close(slave)
                try:
                    deadline = time.monotonic() + 10
                    while len(list(root.glob("*.pid"))) != 3:
                        self.assertLess(time.monotonic(), deadline, "Fake build did not start")
                        time.sleep(0.02)
                    pids = [int(path.read_text()) for path in root.glob("*.pid")]
                    if interrupt == signal.SIGINT:
                        os.write(master, b"\x03")
                    elif interrupt is not None:
                        build.send_signal(interrupt)
                    status = build.wait(timeout=10)
                    output.seek(0)
                    self.assertEqual(status, 128 + interrupt if interrupt else 23, output.read())
                    self.assertTrue(all(not running(pid) for pid in pids), pids)
                    self.assertIsNone(unrelated.poll(), "Cleanup affected an unrelated process")
                finally:
                    os.close(master)
                    if build.poll() is None:
                        build.kill()
                    build.wait()
                    for path in root.glob("*.pid"):
                        try:
                            os.kill(int(path.read_text()), signal.SIGKILL)
                        except OSError as error:
                            if error.errno != errno.ESRCH:
                                raise
                    unrelated.terminate()
                    unrelated.wait()

    def test_ctrl_c_stops_the_process_tree(self):
        self.run_build("interrupt", signal.SIGINT)

    def test_sigterm_stops_the_process_tree(self):
        self.run_build("interrupt", signal.SIGTERM)

    def test_failure_preserves_exit_status_and_stops_children(self):
        self.run_build("failure")


if __name__ == "__main__":
    unittest.main()
