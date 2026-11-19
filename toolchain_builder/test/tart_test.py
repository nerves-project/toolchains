# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class TartTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "o/tmp").mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="tart-test-", dir=ROOT / "o/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        self.script = self.root / "scripts/test-tart.sh"
        shutil.copyfile(ROOT / "scripts/test-tart.sh", self.script)
        self.artifacts = self.root / "artifacts"
        self.artifacts.mkdir()
        tools = self.root / "tools"
        tools.mkdir()
        self.log = self.root / "commands.log"
        stubs = {
            "uname": '#!/bin/sh\nif [ "$1" = -s ]; then echo Darwin; else echo arm64; fi\n',
            "tart": """#!/usr/bin/env bash
set -eu
printf '%s\\n' "$*" >> "$TART_TEST_LOG"
case "$1" in
    pull)
        if [[ -n ${TART_TEST_SETUP_FAIL:-} && $2 = *"$TART_TEST_SETUP_FAIL"* ]]; then exit 7; fi
        ;;
    run)
        echo "$$" > "$TMPDIR/$2.pid"
        exec sleep 300
        ;;
    exec)
        case "$*" in
            */usr/bin/true) test -f "$TMPDIR/$2.pid" ;;
            *tart-guest.sh*)
                if [[ -n ${TART_TEST_FAIL:-} && $* = *"$TART_TEST_FAIL"* ]]; then exit 9; fi
                ;;
            *) test "${TART_TEST_MOUNT_FAIL:-0}" = 0 ;;
        esac
        ;;
    stop)
        for vm in "$@"; do :; done
        kill "$(cat "$TMPDIR/$vm.pid")"
        ;;
esac
""",
        }
        for name, source in stubs.items():
            path = tools / name
            path.write_text(source)
            path.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{tools}:{os.environ['PATH']}", TART_TEST_LOG=str(self.log))
        self.env.pop("GUEST_IMAGES", None)

    def archive(self, name):
        path = self.artifacts / name
        path.write_bytes(b"compiler")
        checksum = hashlib.sha256(path.read_bytes()).hexdigest()
        Path(str(path) + ".sha256").write_text(f"{checksum}  {path.name}\n")
        return path

    def run_script(self, *args, **env):
        return subprocess.run(
            ["/bin/bash", str(self.script), *map(str, args)],
            env=dict(self.env, **env), capture_output=True, text=True, timeout=30,
        )

    def test_all_selects_native_archives_and_continues_after_compiler_failure(self):
        bad = self.archive("bad--darwin_arm.tar.xz")
        good = self.archive("good with spaces--darwin_arm.tar.xz")
        linux = self.archive("compiler--linux_aarch64.tar.xz")
        intel = self.archive("compiler--linux_x86_64.tar.xz")
        result = self.run_script("all", self.artifacts, TART_TEST_FAIL=bad.name)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(f"FAIL\tsequoia\t{bad.name}", result.stdout)
        self.assertIn(f"PASS\tgolden-gate\t{good.name}", result.stdout)
        self.assertIn(f"PASS\tubuntu-22.04\t{linux.name}", result.stdout)
        self.assertIn(f"PASS\tubuntu-24.04\t{linux.name}", result.stdout)
        self.assertIn(f"PASS\trocky-9\t{linux.name}", result.stdout)
        self.assertIn(f"SKIP {intel.name}", result.stdout)
        calls = self.log.read_text()
        self.assertEqual(calls.count(":ro,tag=nerves-toolchains"), 10)
        self.assertEqual(calls.count("stop --timeout 5"), 5)
        self.assertEqual(calls.count("delete "), 5)
        self.assertTrue(list((self.root / "o/tart-tests").glob("run-*/results.tsv")))

    def test_single_archive_only_runs_its_host_guests(self):
        archive = self.archive("compiler with spaces--linux_aarch64.tar.xz")
        result = self.run_script(archive)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"PASS\tubuntu-22.04\t{archive.name}", result.stdout)
        self.assertIn(f"PASS\tubuntu-24.04\t{archive.name}", result.stdout)
        self.assertIn(f"PASS\trocky-9\t{archive.name}", result.stdout)
        self.assertNotIn("macos-", self.log.read_text())
        self.assertIn("SKIP macOS guests", result.stdout)

    def test_guest_images_environment_selects_full_image_names(self):
        mac = self.archive("compiler--darwin_arm.tar.xz")
        linux = self.archive("compiler--linux_aarch64.tar.xz")
        images = [
            "registry.example.com/tests/macos-golden-gate-base:smoke",
            "registry.example.com/tests/ubuntu:22.04",
        ]
        result = self.run_script("all", self.artifacts, GUEST_IMAGES="\n".join(images))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.log.read_text().splitlines()
        self.assertEqual([call for call in calls if call.startswith("pull ")],
                         [f"pull {image}" for image in images])
        self.assertIn(f"PASS\tgolden-gate\t{mac.name}", result.stdout)
        self.assertIn(f"PASS\tubuntu-22.04\t{linux.name}", result.stdout)
        self.assertNotIn("sequoia", result.stdout)

    def test_rejects_bad_checksums_and_incompatible_selections_before_starting_vms(self):
        archive = self.archive("compiler--darwin_arm.tar.xz")
        checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
        for sidecar in (
            f"{checksum}  wrong-name.tar.xz\n",
            f"{checksum}  {archive.name}\n\n",
            f"{'0' * 64}  {archive.name}\n",
        ):
            Path(str(archive) + ".sha256").write_text(sidecar)
            self.assertNotEqual(self.run_script(archive).returncode, 0)
            self.assertFalse(self.log.exists())
        intel = self.archive("compiler--linux_x86_64.tar.xz")
        self.assertNotEqual(self.run_script(intel).returncode, 0)
        self.assertFalse(self.log.exists())
        empty = self.root / "empty"
        empty.mkdir()
        result = self.run_script("all", empty)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No compatible", result.stderr)

    def test_golden_gate_pull_failure_is_reported_without_fallback(self):
        archive = self.archive("compiler--darwin_arm.tar.xz")
        result = self.run_script(archive, TART_TEST_SETUP_FAIL="golden-gate")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(f"PASS\tsequoia\t{archive.name}", result.stdout)
        self.assertIn("FAIL\tgolden-gate", result.stdout)
        self.assertNotIn("tahoe", self.log.read_text())

    def test_failed_guest_does_not_skip_other_guests(self):
        archive = self.archive("compiler--darwin_arm.tar.xz")
        result = self.run_script(archive, TART_TEST_SETUP_FAIL="sequoia")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("FAIL\tsequoia", result.stdout)
        self.assertIn(f"PASS\tgolden-gate\t{archive.name}", result.stdout)

    def test_guest_setup_failure_still_stops_and_deletes_vms(self):
        archive = self.archive("compiler--linux_aarch64.tar.xz")
        result = self.run_script(archive, TART_TEST_MOUNT_FAIL="1")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        calls = self.log.read_text()
        self.assertIn("stop --timeout 5", calls)
        self.assertIn("delete ", calls)
        self.assertNotIn("tart-guest.sh", calls)

    def test_guest_validates_requested_linux_version_distribution_and_architecture(self):
        source = (ROOT / "test/tart-guest.sh").read_text().split("\nWORK=", 1)[0]
        script = source.replace("/etc/os-release", '"$TART_TEST_OS_RELEASE"')
        release = self.root / "os-release"
        uname = self.root / "tools/uname"
        uname.write_text('#!/bin/sh\necho "$TART_TEST_ARCH"\n')
        env = dict(self.env, TART_TEST_OS_RELEASE=str(release))
        for requested, distribution, actual, arch, success in (
            ("ubuntu-22.04", "ubuntu", "22.04", "aarch64", True),
            ("ubuntu-24.04", "ubuntu", "24.04", "aarch64", True),
            ("ubuntu-24.04", "ubuntu", "22.04", "aarch64", False),
            ("ubuntu-24.04", "debian", "24.04", "aarch64", False),
            ("ubuntu-24.04", "ubuntu", "24.04", "x86_64", False),
            ("rocky-9", "rocky", "9.7", "aarch64", True),
            ("rocky-9", "rocky", "10.1", "aarch64", False),
            ("rocky-9", "ubuntu", "9.7", "aarch64", False),
            ("rocky-9", "rocky", "9.7", "x86_64", False),
        ):
            with self.subTest(requested=requested, distribution=distribution, actual=actual, arch=arch):
                release.write_text(f'ID={distribution}\nVERSION_ID="{actual}"\n')
                result = subprocess.run(
                    ["/bin/sh", "-c", script, "tart-guest.sh", requested, "unused", "unused"],
                    env=dict(env, TART_TEST_ARCH=arch), capture_output=True, text=True,
                )
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def test_guest_checks_optional_tools_and_propagates_compiler_failure(self):
        tools = self.root / "fake-tools"
        tools.mkdir()
        uname = tools / "uname"
        uname.write_text("#!/bin/sh\necho arm64\n")
        uname.chmod(0o755)
        sw_vers = tools / "sw_vers"
        sw_vers.write_text("#!/bin/sh\necho 15.0\n")
        sw_vers.chmod(0o755)
        source = self.root / "toolchain"
        (source / "bin").mkdir(parents=True)
        driver = (
            "#!/bin/sh\n"
            "name=$(basename \"$0\")\n"
            "printf '%s %s\\n' \"$name\" \"$*\" >> \"$TART_TEST_LOG\"\n"
            "[ \"$name\" != \"${TART_TEST_FAIL:-}\" ] || exit 9\n"
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
        env = dict(
            os.environ, PATH=f"{tools}:{os.environ['PATH']}",
            TMPDIR=str(guest_tmp), TART_TEST_LOG=str(log),
        )
        command = [
            "/bin/sh", str(ROOT / "test/tart-guest.sh"), "sequoia",
            str(archive), str(ROOT / "test/smoketest/main.cpp"),
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
            command, env=dict(env, TART_TEST_FAIL="target-g++"), capture_output=True,
        )
        self.assertEqual(result.returncode, 9)
        self.assertEqual(list(guest_tmp.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
