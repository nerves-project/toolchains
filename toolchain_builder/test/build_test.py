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


class BuildDiskImageTest(unittest.TestCase):
    def run_init(self, modern):
        source = BUILD.read_text()
        init = source[source.index("\ninit()\n"):source.index("\ngcc_tuple()\n")]
        with tempfile.TemporaryDirectory(prefix="toolchain-image-") as directory:
            root = Path(directory)
            script = """
set -e
diskutil() {
    printf 'diskutil %s\\n' "$*" >> "$COMMAND_LOG"
    if [[ $* = "image create blank --help" ]]; then
        [[ $MODERN = yes ]]
    elif [[ $* = "image attach --noMount "* ]]; then
        echo /dev/disk99
    fi
}
hdiutil() { printf 'hdiutil %s\\n' "$*" >> "$COMMAND_LOG"; }
ln() { printf 'ln %s\\n' "$*" >> "$COMMAND_LOG"; }
""" + init + "\ninit\n"
            env = dict(
                os.environ,
                BUILD_OS="darwin",
                WORK_DIR=str(root / "work"),
                WORK_DMG=str(root / "work.dmg"),
                WORK_DMG_VOLNAME="test-volume",
                GCC_INSTALL_DIR=str(root / "work" / "x-tools"),
                DL_DIR=str(root / "downloads"),
                COMMAND_LOG=str(root / "commands"),
                MODERN="yes" if modern else "no",
            )
            result = subprocess.run(
                ["bash", "-c", script], env=env, capture_output=True, text=True
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            commands = (root / "commands").read_text().splitlines()
            self.assertIn("diskutil eject /Volumes/test-volume", commands)
            self.assertEqual(commands[-1], f"ln -s /Volumes/test-volume {root / 'work'}")
            return commands, root / "work.dmg"

    def test_modern_macos_creates_case_sensitive_image_without_hdiutil(self):
        commands, image = self.run_init(modern=True)
        self.assertIn(f"diskutil image create blank --size 32g --fs None {image}", commands)
        self.assertIn(f"diskutil image attach --noMount {image}", commands)
        self.assertIn("diskutil eraseDisk HFSX test-volume /dev/disk99", commands)
        self.assertFalse(any(command.startswith("hdiutil ") for command in commands))

    def test_older_macos_uses_hdiutil_for_image_creation_and_attachment(self):
        commands, image = self.run_init(modern=False)
        self.assertIn(
            f"hdiutil create -size 32g -fs Case-sensitive HFS+ -volname test-volume {image}",
            commands,
        )
        self.assertIn(f"hdiutil attach {image}", commands)
        self.assertFalse(any("eraseDisk" in command for command in commands))


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
