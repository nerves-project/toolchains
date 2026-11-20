# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONFIG = "armv7-nerves-linux-gnueabihf--gcc16"


class TartBuildTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "o/tmp").mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="tart-build-test-", dir=ROOT / "o/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ("Makefile", "VERSION", "LICENSE", "README.md", "build_native.sh", "build_with_tart.sh"):
            shutil.copyfile(ROOT / name, self.root / name)
        for name in ("scripts", "configs", "defaults", "patches"):
            shutil.copytree(ROOT / name, self.root / name)
        tools = self.root / "tools"
        tools.mkdir()
        self.log = self.root / "commands.log"
        self.guest_output = self.root / "guest-output"
        self.guest_output.mkdir()
        for name, source in {
            "uname": '#!/bin/sh\nif [ "$1" = -s ]; then echo Darwin; else echo arm64; fi\n',
            "tart": """#!/usr/bin/env bash
set -eu
printf '%s\\n' "$*" >> "$TART_TEST_LOG"
case "$1" in
    run)
        echo "$$" > "$TMPDIR/$2.pid"
        exec sleep 300
        ;;
    exec)
        case "$*" in
            */usr/bin/true) test -f "$TMPDIR/$2.pid" ;;
            */bin/bash\\ -s\\ --*)
                cat > "$TART_TEST_SCRIPT"
                exit "${TART_TEST_BUILD_STATUS:-0}"
                ;;
            *tar\\ -C*)
                exec tar -C "$TART_TEST_OUTPUT" -cf - .
                ;;
        esac
        ;;
    stop)
        for vm in "$@"; do :; done
        kill "$(cat "$TMPDIR/$vm.pid")"
        ;;
esac
""",
        }.items():
            path = tools / name
            path.write_text(source)
            path.chmod(0o755)
        self.env = dict(
            os.environ, PATH=f"{tools}:{os.environ['PATH']}", TART_TEST_LOG=str(self.log),
            TART_TEST_SCRIPT=str(self.root / "guest-script"), TART_TEST_OUTPUT=str(self.guest_output),
        )

    def archive(self, host, contents=b"compiler"):
        release = (self.root / "VERSION").read_text().strip()
        name = f"armv7-nerves-linux-gnueabihf--gcc-16.2.0-glibc-2.44-linux-6.12.112--{release}--{host}.tar.xz"
        archive = self.guest_output / name
        archive.write_bytes(contents)
        digest = hashlib.sha256(contents).hexdigest()
        Path(str(archive) + ".sha256").write_text(f"{digest}  {name}\n")
        return archive

    def run_script(self, guest, config=CONFIG, **env):
        return subprocess.run(
            ["/bin/bash", str(self.root / "build_with_tart.sh"), guest, config],
            env=dict(self.env, **env), capture_output=True, text=True, timeout=30,
        )

    def test_builds_both_host_types_and_exports_verified_pairs(self):
        for guest, host, image in (
            ("macos", "darwin_arm", "macos-sequoia-base:latest"),
            ("linux", "linux_aarch64", "ubuntu:22.04"),
        ):
            with self.subTest(guest=guest):
                archive = self.archive(host)
                result = self.run_script(guest)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                output = self.root / "o/artifacts" / archive.name
                self.assertEqual(output.read_bytes(), b"compiler")
                self.assertEqual(Path(str(output) + ".sha256").read_bytes(), Path(str(archive) + ".sha256").read_bytes())
                self.assertIn(f"pull ghcr.io/cirruslabs/{image}", self.log.read_text())
                self.assertIn(f"/bin/bash -s -- {CONFIG}", self.log.read_text())
                self.assertIn(":ro,tag=nerves-build", self.log.read_text())
                self.assertIn("stop --timeout 5", self.log.read_text())
                self.assertIn("delete ", self.log.read_text())
                archive.unlink()
                Path(str(archive) + ".sha256").unlink()

    def test_build_failure_is_propagated_without_publishing(self):
        self.archive("darwin_arm")
        result = self.run_script("macos", TART_TEST_BUILD_STATUS="23")
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertEqual(list((self.root / "o/artifacts").iterdir()), [])
        self.assertIn("stop --timeout 5", self.log.read_text())
        self.assertIn("delete ", self.log.read_text())

    def test_export_rejects_bad_checksum_and_wrong_host(self):
        archive = self.archive("darwin_arm")
        archive.write_bytes(b"changed")
        self.assertNotEqual(self.run_script("macos").returncode, 0)
        self.assertEqual(list((self.root / "o/artifacts").iterdir()), [])
        archive.unlink()
        Path(str(archive) + ".sha256").unlink()
        self.archive("linux_aarch64")
        self.assertNotEqual(self.run_script("macos").returncode, 0)
        self.assertEqual(list((self.root / "o/artifacts").iterdir()), [])

    def test_existing_pair_is_verified_and_skipped_without_a_vm(self):
        archive = self.archive("darwin_arm")
        output = self.root / "o/artifacts"
        output.mkdir(parents=True)
        for path in (archive, Path(str(archive) + ".sha256")):
            shutil.copyfile(path, output / path.name)
        result = self.run_script("macos")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Skipping", result.stdout)
        self.assertFalse(self.log.exists())
        (output / archive.name).write_bytes(b"changed")
        self.assertNotEqual(self.run_script("macos").returncode, 0)
        self.assertFalse(self.log.exists())

    def test_partial_existing_artifact_is_not_overwritten(self):
        archive = self.archive("darwin_arm")
        output = self.root / "o/artifacts"
        output.mkdir(parents=True)
        for name in (archive.name, archive.name + ".sha256"):
            with self.subTest(existing=name):
                existing = output / name
                existing.write_bytes(b"keep this")
                self.assertNotEqual(self.run_script("macos").returncode, 0)
                self.assertEqual(existing.read_bytes(), b"keep this")
                self.assertEqual(list(output.iterdir()), [existing])
                existing.unlink()

    def test_rejects_unknown_platforms_before_starting_a_vm(self):
        for guest in ("sequoia", "ubuntu:22.04", "windows"):
            with self.subTest(guest=guest):
                result = self.run_script(guest)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("<macos|linux>", result.stderr)
                self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
