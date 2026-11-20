# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ToolchainGuestTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "o/tmp").mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="guest-test-", dir=ROOT / "o/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.env = dict(os.environ, PATH=f"{self.tools}:{os.environ['PATH']}")

    def test_guest_validates_requested_linux_version_distribution_and_architecture(self):
        source = (ROOT / "scripts/toolchain-guest.sh").read_text().split("\nWORK=", 1)[0]
        script = source.replace("/etc/os-release", '"$GUEST_TEST_OS_RELEASE"')
        release = self.root / "os-release"
        uname = self.tools / "uname"
        uname.write_text('#!/bin/sh\necho "$GUEST_TEST_ARCH"\n')
        uname.chmod(0o755)
        env = dict(self.env, GUEST_TEST_OS_RELEASE=str(release))
        for requested, distribution, actual, arch, expected_arch, success in (
            ("ubuntu-22.04", "ubuntu", "22.04", "aarch64", None, True),
            ("ubuntu-24.04", "ubuntu", "24.04", "aarch64", None, True),
            ("ubuntu-24.04", "ubuntu", "22.04", "aarch64", None, False),
            ("ubuntu-24.04", "debian", "24.04", "aarch64", None, False),
            ("ubuntu-24.04", "ubuntu", "24.04", "x86_64", None, False),
            ("rocky-9", "rocky", "9.7", "aarch64", None, True),
            ("rocky-9", "rocky", "10.1", "aarch64", None, False),
            ("rocky-9", "ubuntu", "9.7", "aarch64", None, False),
            ("rocky-9", "rocky", "9.7", "x86_64", None, False),
            ("ubuntu-22.04", "ubuntu", "22.04", "x86_64", "x86_64", True),
            ("ubuntu-24.04", "ubuntu", "24.04", "x86_64", "x86_64", True),
            ("alpine-3.24", "alpine", "3.24.4", "x86_64", "x86_64", True),
            ("alpine-3.24", "alpine", "3.23.8", "x86_64", "x86_64", False),
            ("alpine-3.24", "ubuntu", "3.24.4", "x86_64", "x86_64", False),
            ("alpine-3.24", "alpine", "3.24.4", "aarch64", "x86_64", False),
        ):
            with self.subTest(requested=requested, distribution=distribution, actual=actual, arch=arch):
                release.write_text(f'ID={distribution}\nVERSION_ID="{actual}"\n')
                command = ["/bin/sh", "-c", script, "toolchain-guest.sh", requested, "unused", "unused"]
                if expected_arch:
                    command.append(expected_arch)
                result = subprocess.run(
                    command,
                    env=dict(env, GUEST_TEST_ARCH=arch), capture_output=True, text=True,
                )
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def test_guest_checks_optional_tools_and_propagates_compiler_failure(self):
        uname = self.tools / "uname"
        uname.write_text("#!/bin/sh\necho arm64\n")
        uname.chmod(0o755)
        sw_vers = self.tools / "sw_vers"
        sw_vers.write_text("#!/bin/sh\necho 15.0\n")
        sw_vers.chmod(0o755)
        source = self.root / "toolchain"
        (source / "bin").mkdir(parents=True)
        driver = (
            "#!/bin/sh\n"
            "name=$(basename \"$0\")\n"
            "printf '%s %s\\n' \"$name\" \"$*\" >> \"$GUEST_TEST_LOG\"\n"
            "[ \"$name\" != \"${GUEST_TEST_FAIL:-}\" ] || exit 9\n"
            "while [ \"$#\" -gt 0 ]; do\n"
            "  if [ \"$1\" = -o ]; then shift; touch \"$1\"; fi\n"
            "  shift\n"
            "done\n"
        )
        for name in ("gcc", "g++", "as", "ld", "gfortran", "gdb", "readelf"):
            path = source / "bin" / f"target-{name}"
            path.write_text(driver)
            path.chmod(0o755)
        archive = self.root / "archive.tar.xz"
        log = self.root / "guest-commands.log"
        guest_tmp = self.root / "guest-tmp"
        guest_tmp.mkdir()
        env = dict(self.env, TMPDIR=str(guest_tmp), GUEST_TEST_LOG=str(log))
        command = [
            "/bin/sh", str(ROOT / "scripts/toolchain-guest.sh"), "sequoia",
            str(archive), str(ROOT / "scripts/smoketest/main.cpp"),
        ]
        for enabled in (False, True):
            (source / "ct-ng.config").write_text(
                "CT_CC_LANG_FORTRAN=y\nCT_GDB_CROSS=y\n" if enabled else ""
            )
            with tarfile.open(archive, "w:xz") as output:
                output.add(source, arcname="toolchain")
            subprocess.run(command, env=env, check=True, capture_output=True)
            calls = log.read_text()
            self.assertIn("-flto", calls)
            self.assertEqual("target-gfortran " in calls, enabled)
            self.assertEqual("target-gdb " in calls, enabled)
            self.assertEqual(list(guest_tmp.iterdir()), [])
            log.unlink()
        result = subprocess.run(
            command, env=dict(env, GUEST_TEST_FAIL="target-g++"), capture_output=True,
        )
        self.assertEqual(result.returncode, 9)
        self.assertEqual(list(guest_tmp.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
