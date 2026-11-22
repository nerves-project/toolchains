# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import hashlib
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
TARGET = "test-nerves-linux-gnu"
RELEASE = (ROOT / "VERSION").read_text().strip()


class ToolchainTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "o/tmp").mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="archive-test-", dir=ROOT / "o/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.install = self.root / "installed"
        (self.install / "bin").mkdir(parents=True)
        (self.install / "bin" / f"{TARGET}-gcc").write_text("compiler")
        (self.install / "bin" / f"{TARGET}-cc").symlink_to(f"{TARGET}-gcc")
        self.config = self.install / "ct-ng.config"
        self.config.write_text(
            'CT_GCC_VERSION="99.2.1"\nCT_LINUX_VERSION="6.12.3"\n'
            'CT_LIBC_GLIBC=y\nCT_GLIBC_VERSION="2.99"\n'
        )
        self.output = self.root / "archives"

    def helper(self, *args):
        return subprocess.run(
            ["bash", str(ROOT / "scripts/archive.sh"), *map(str, args)],
            capture_output=True, text=True,
        )

    def package(self, host="linux_x86_64", **env):
        return subprocess.run(
            ["bash", str(ROOT / "scripts/package.sh"), str(self.install), str(self.output), host],
            env=dict(os.environ, **env), capture_output=True, text=True,
        )

    def test_packaging_preserves_installation_and_refuses_replacement(self):
        for name in ("toolchain-builder.metadata", "toolchain-builder.version"):
            (self.install / name).write_text("obsolete")
        recipe = self.install / "share/toolchain-builder"
        recipe.mkdir(parents=True)
        (recipe / "build-info.json").write_text("{}")
        result = self.package()
        self.assertEqual(result.returncode, 0, result.stderr)
        archive = next(self.output.glob("*.tar.xz"))
        expected = f"{TARGET}--gcc-99.2.1-glibc-2.99-linux-6.12.3--{RELEASE}--linux_x86_64.tar.xz"
        self.assertEqual(archive.name, expected)
        original = archive.read_bytes()
        digest = hashlib.sha256(original).hexdigest()
        self.assertEqual(Path(str(archive) + ".sha256").read_text(), f"{digest}  {expected}\n")
        self.assertEqual(sorted(path.name for path in self.output.iterdir()), [expected, expected + ".sha256"])
        with tarfile.open(archive, "r:xz") as contents:
            names = contents.getnames()
            self.assertIn("installed/ct-ng.config", names)
            for name in ("toolchain-builder.metadata", "toolchain-builder.version", "share/toolchain-builder/build-info.json"):
                self.assertNotIn(f"installed/{name}", names)
            self.assertEqual(contents.getmember(f"installed/bin/{TARGET}-cc").linkname, f"{TARGET}-gcc")
        self.assertEqual((self.install / "toolchain-builder.metadata").read_text(), "obsolete")
        compiler = self.install / "bin" / f"{TARGET}-gcc"
        compiler.write_text("changed")
        self.assertNotEqual(self.package().returncode, 0)
        self.assertEqual(archive.read_bytes(), original)
        self.assertEqual(compiler.read_text(), "changed")
        self.assertEqual(self.package("darwin_arm").returncode, 0)
        self.assertEqual(archive.read_bytes(), original)

    def test_archive_lookup_requires_matching_host_release_track_and_checksum_pair(self):
        self.assertEqual(self.package().returncode, 0)
        archive = next(self.output.glob("*.tar.xz"))
        result = self.helper("--find", self.output, f"{TARGET}--gcc99", "linux_x86_64", RELEASE)
        self.assertEqual(result.stdout.strip(), str(archive))
        for config, host, release in (
            (f"{TARGET}--gcc15", "linux_x86_64", RELEASE),
            (f"{TARGET}--gcc99", "darwin_arm", RELEASE),
            (f"{TARGET}--gcc99", "linux_x86_64", "2000.01.1"),
        ):
            self.assertEqual(self.helper("--find", self.output, config, host, release).stdout, "")
        Path(str(archive) + ".sha256").unlink()
        self.assertEqual(
            self.helper("--find", self.output, f"{TARGET}--gcc99", "linux_x86_64", RELEASE).stdout, "",
        )

    def test_naming_reads_resolved_versions_without_creating_metadata(self):
        self.config.write_text(self.config.read_text().replace("GLIBC", "MUSL"))
        before = sorted(self.root.rglob("*"))
        result = self.helper("--name", self.install, "darwin_arm")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.strip(),
            f"{TARGET}--gcc-99.2.1-musl-2.99-linux-6.12.3--{RELEASE}--darwin_arm.tar.xz",
        )
        self.assertEqual(sorted(self.root.rglob("*")), before)
        self.config.write_text(self.config.read_text().replace("99.2.1", "../outside"))
        result = self.helper("--name", self.install, "darwin_arm")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid archive name component", result.stderr)

    def test_windows_package_recognizes_exe_and_dereferences_links(self):
        compiler = self.install / "bin" / f"{TARGET}-gcc"
        executable = compiler.with_name(compiler.name + ".exe")
        compiler.rename(executable)
        alias = self.install / "bin" / f"{TARGET}-cc"
        alias.unlink()
        alias.with_name(alias.name + ".exe").symlink_to(executable.name)
        (self.install / "bin" / f"{TARGET}-gcc-version.exe").hardlink_to(executable)
        self.config.write_text(
            self.config.read_text() + 'CT_CANADIAN=y\nCT_HOST="x86_64-w64-mingw32"\n',
        )
        result = self.package("mingw_x86_64")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        archive = next(self.output.glob("*.tar.xz"))
        self.assertEqual(
            archive.name,
            f"{TARGET}--gcc-99.2.1-glibc-2.99-linux-6.12.3--{RELEASE}--mingw_x86_64.tar.xz",
        )
        with tarfile.open(archive, "r:xz") as contents:
            self.assertFalse(any(member.issym() or member.islnk() for member in contents))
            self.assertEqual(
                contents.extractfile(f"installed/bin/{TARGET}-cc.exe").read(), b"compiler",
            )
        config = f"{TARGET}--gcc99--mingw_x86_64"
        result = self.helper("--find", self.output, config, "mingw_x86_64", RELEASE)
        self.assertEqual(result.stdout.strip(), str(archive))
        self.assertNotEqual(
            self.helper("--find", self.output, config, "linux_x86_64", RELEASE).returncode, 0,
        )

    def test_compression_failure_does_not_publish_or_damage_installation(self):
        xz = self.root / "xz"
        xz.write_text("#!/bin/sh\nexit 9\n")
        xz.chmod(0o755)
        result = self.package(PATH=f"{self.root}:{os.environ['PATH']}")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(self.output.iterdir()), [])
        self.assertEqual((self.install / "bin" / f"{TARGET}-gcc").read_text(), "compiler")

    def test_smoke_test_relocates_archive_and_rejects_bad_checksum(self):
        compiler = self.install / "bin" / f"{TARGET}-g++"
        compiler.write_text(
            '#!/usr/bin/env bash\nargs=()\nfor arg; do\n'
            'if [[ "$arg" != -Wl,--build-id=none ]]; then args+=("$arg"); fi\n'
            'done\nexec c++ "${args[@]}"\n'
        )
        compiler.chmod(0o755)
        self.assertEqual(self.package().returncode, 0)
        archive = next(self.output.glob("*.tar.xz"))
        executable = self.root / "smoketest.elf"
        command = ["bash", str(ROOT / "scripts/smoketest.sh"), str(archive), str(executable)]
        result = subprocess.run(command, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(executable.is_file())
        executable.unlink()
        archive.write_text("corrupted")
        self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
        self.assertFalse(executable.exists())

    def test_explicit_config_validation_handles_defaults_missing_keys_and_empty_base(self):
        base = self.root / "base"
        resolved = self.root / ".config"
        base.write_text('CT_GCC_V_15=y\nCT_GCC_VERSION="15.3.0"\n# CT_CREATE_LDSO_CONF is not set\n')
        good = '# CT_CREATE_LDSO_CONF is not set\nCT_GCC_VERSION="15.3.0"\nCT_GCC_V_15=y\nCT_OTHER=y\n'
        resolved.write_text(good)
        self.assertEqual(self.helper("--check-config", base, resolved).returncode, 0)
        resolved.write_text(good.replace('"15.3.0"', '"15.4.0"'))
        result = self.helper("--check-config", base, resolved)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('CT_GCC_VERSION: requested "15.3.0", resolved "15.4.0"', result.stderr)
        resolved.write_text(good.replace("CT_GCC_V_15=y\n", ""))
        self.assertIn("CT_GCC_V_15: requested y, resolved <missing>", self.helper("--check-config", base, resolved).stderr)
        base.write_text("")
        self.assertEqual(self.helper("--check-config", base, resolved).returncode, 0)


if __name__ == "__main__":
    unittest.main()
