# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONFIG = "armv7-nerves-linux-gnueabihf--gcc16"
WINDOWS_CONFIG = "aarch64-nerves-linux-gnu--gcc16"


class DockerBuildTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "o/tmp").mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="docker-build-test-", dir=ROOT / "o/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ("Makefile", "VERSION", "LICENSE", "README.md", "build_native.sh", "build_with_docker.sh"):
            shutil.copyfile(ROOT / name, self.root / name)
        for name in ("scripts", "configs", "defaults", "patches"):
            shutil.copytree(ROOT / name, self.root / name)
        tools = self.root / "tools"
        tools.mkdir()
        docker = tools / "docker"
        docker.write_text("""#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import sys
args = sys.argv[1:]
with open(os.environ["DOCKER_BUILD_TEST_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args[0] in ("build", "run"):
    script = sys.stdin.read()
    Path(os.environ["DOCKER_BUILD_TEST_SCRIPTS"], args[0]).write_text(script)
    sys.exit(int(os.environ.get("DOCKER_BUILD_TEST_" + args[0].upper() + "_STATUS", "0")))
if args[0] == "cp":
    shutil.copytree(os.environ["DOCKER_BUILD_TEST_OUTPUT"], args[2], dirs_exist_ok=True)
""")
        docker.chmod(0o755)
        self.log = self.root / "commands.jsonl"
        self.output = self.root / "container-output"
        self.output.mkdir()
        self.scripts = self.root / "container-scripts"
        self.scripts.mkdir()
        self.env = dict(
            os.environ, PATH=f"{tools}:{os.environ['PATH']}", DOCKER_BUILD_TEST_LOG=str(self.log),
            DOCKER_BUILD_TEST_OUTPUT=str(self.output), DOCKER_BUILD_TEST_SCRIPTS=str(self.scripts),
            HOST_OS="linux", HOST_ARCH="x86_64",
        )

    def archive(self, host="linux_x86_64", target="armv7-nerves-linux-gnueabihf"):
        release = (self.root / "VERSION").read_text().strip()
        name = f"{target}--gcc-16.2.0-glibc-2.44-linux-6.12.112--{release}--{host}.tar.xz"
        archive = self.output / name
        archive.write_bytes(b"compiler")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        Path(str(archive) + ".sha256").write_text(f"{digest}  {name}\n")
        return archive

    def run_script(self, config=CONFIG, **env):
        return subprocess.run(
            ["/bin/bash", str(self.root / "build_with_docker.sh"), config],
            env=dict(self.env, **env), capture_output=True, text=True, timeout=30,
        )

    def calls(self, command):
        return [
            args for args in map(json.loads, self.log.read_text().splitlines())
            if args[0] == command
        ]

    def test_build_uses_amd64_source_snapshot_and_exports_verified_pair(self):
        archive = self.archive()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        published = self.root / "o/artifacts" / archive.name
        self.assertEqual(published.read_bytes(), archive.read_bytes())
        self.assertEqual(
            Path(str(published) + ".sha256").read_bytes(),
            Path(str(archive) + ".sha256").read_bytes(),
        )
        build = self.calls("build")[0]
        self.assertIn("BASE=docker.io/library/ubuntu:22.04", build)
        self.assertEqual(build[build.index("--platform") + 1], "linux/amd64")
        run = self.calls("run")[0]
        self.assertEqual(run[run.index("--platform") + 1], "linux/amd64")
        self.assertEqual(run[-3:], [CONFIG, "linux", "x86_64"])
        self.assertNotIn("--rm", run)
        snapshot = next((self.root / "o/docker-builds").glob("run-*/source"))
        self.assertIn(f"type=bind,source={snapshot},target=/source,readonly", run)
        self.assertTrue((snapshot / "Makefile").is_file())
        self.assertTrue((snapshot / f"configs/{CONFIG}.defconfig").is_file())
        self.assertFalse((snapshot / "o").exists())
        self.assertEqual(
            self.calls("rm"), [["rm", "--force", run[run.index("--name") + 1]]],
        )

    def test_image_and_toolchain_build_failures_preserve_exit_status(self):
        for stage, status in (("BUILD", 17), ("RUN", 23)):
            with self.subTest(stage=stage):
                result = self.run_script(**{f"DOCKER_BUILD_TEST_{stage}_STATUS": str(status)})
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assertEqual(self.calls("cp"), [])
                self.assertEqual(len(self.calls("rm")), 1)
                self.assertEqual(list((self.root / "o/artifacts").iterdir()), [])
                self.log.unlink()

    def test_canadian_build_exports_windows_pair_and_skips_completed_build(self):
        archive = self.archive("mingw_x86_64", "aarch64-nerves-linux-gnu")
        result = self.run_script(WINDOWS_CONFIG, HOST_OS="mingw")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        build = self.calls("build")[0]
        self.assertEqual(
            build[build.index("--tag") + 1], "nerves-toolchain-builder:ubuntu-22.04-mingw",
        )
        self.assertIn(
            "EXTRA_PACKAGES=gcc-mingw-w64-x86-64-posix g++-mingw-w64-x86-64-posix", build,
        )
        run = self.calls("run")[0]
        self.assertEqual(run[run.index("--platform") + 1], "linux/amd64")
        self.assertEqual(run[-3:], [WINDOWS_CONFIG, "mingw", "x86_64"])
        self.assert_guest_host(run[-3:])
        self.assertEqual((self.root / "o/artifacts" / archive.name).read_bytes(), b"compiler")
        calls = self.log.read_text()
        result = self.run_script(WINDOWS_CONFIG, HOST_OS="mingw")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Skipping", result.stdout)
        self.assertEqual(self.log.read_text(), calls)

    def test_canadian_build_rejects_linux_host_archive(self):
        self.archive("linux_x86_64", "aarch64-nerves-linux-gnu")
        result = self.run_script(WINDOWS_CONFIG, HOST_OS="mingw")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected one mingw_x86_64 archive", result.stderr)
        self.assertEqual(list((self.root / "o/artifacts").iterdir()), [])

    def assert_guest_host(self, args):
        guest = self.root / "guest"
        guest.mkdir()
        (guest / "build_native.sh").write_text(
            'printf "%s\\n" "$HOST_OS" "$HOST_ARCH" "$1" > "$(dirname "$0")/host"\n',
        )
        script = (self.scripts / "run").read_text().replace(
            "WORKSPACE=/tmp/nerves-toolchain-builder", f"WORKSPACE={guest}",
        )
        result = subprocess.run(
            ["/bin/bash", "-c", """
uname() { if [[ $1 = -s ]]; then echo Linux; else echo x86_64; fi; }
tar() { cat >/dev/null; }
""" + script, "guest-build", *args],
            env=self.env, capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((guest / "host").read_text().splitlines(), [args[1], args[2], args[0]])

    def test_same_target_config_builds_both_linux_and_windows_hosts(self):
        self.archive()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_guest_host(self.calls("run")[0][-3:])
        for path in self.output.iterdir():
            path.unlink()
        self.archive("mingw_x86_64")
        result = self.run_script(HOST_OS="mingw")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(list((self.root / "o/artifacts").glob("*.tar.xz"))), 2)
        self.assertEqual(len(self.calls("run")), 2)

    def test_rejects_unsupported_hosts_without_docker(self):
        for host, arch in (("darwin", "x86_64"), ("mingw", "aarch64"), ("linux", "aarch64")):
            with self.subTest(host=host, arch=arch):
                result = self.run_script(HOST_OS=host, HOST_ARCH=arch)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Unsupported Docker toolchain host", result.stderr)
                self.assertFalse(self.log.exists())

    def test_export_rejects_bad_checksum_wrong_host_and_missing_archives(self):
        archive = self.archive()
        archive.write_bytes(b"changed")
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(list((self.root / "o/artifacts").iterdir()), [])
        archive.unlink()
        Path(str(archive) + ".sha256").unlink()
        archive = self.archive("linux_aarch64")
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(list((self.root / "o/artifacts").iterdir()), [])
        archive.unlink()
        Path(str(archive) + ".sha256").unlink()
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected one linux_x86_64 archive", result.stderr)

    def test_existing_pair_is_verified_and_skipped_without_docker(self):
        archive = self.archive()
        output = self.root / "o/artifacts"
        output.mkdir(parents=True)
        for path in (archive, Path(str(archive) + ".sha256")):
            shutil.copyfile(path, output / path.name)
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Skipping", result.stdout)
        self.assertFalse(self.log.exists())
        (output / archive.name).write_bytes(b"changed")
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_partial_existing_artifact_or_checksum_is_not_overwritten(self):
        archive = self.archive()
        output = self.root / "o/artifacts"
        output.mkdir(parents=True)
        for name in (archive.name, archive.name + ".sha256"):
            with self.subTest(existing=name):
                existing = output / name
                existing.write_bytes(b"keep this")
                self.assertNotEqual(self.run_script().returncode, 0)
                self.assertEqual(existing.read_bytes(), b"keep this")
                self.assertEqual(list(output.iterdir()), [existing])
                existing.unlink()

    def test_rejects_unknown_configs_without_docker(self):
        for config in ("missing", "../Makefile", "linux"):
            with self.subTest(config=config):
                result = self.run_script(config)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Unknown toolchain config", result.stderr)
                self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
