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


class ContainerTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "o/tmp").mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="container-test-", dir=ROOT / "o/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        self.script = self.root / "scripts/test-container.sh"
        shutil.copyfile(ROOT / "scripts/test-container.sh", self.script)
        self.artifacts = self.root / "archives with spaces"
        self.artifacts.mkdir()
        tools = self.root / "tools"
        tools.mkdir()
        docker = tools / "docker"
        docker.write_text("""#!/usr/bin/env python3
import json
import os
import sys
args = sys.argv[1:]
with open(os.environ["CONTAINER_TEST_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args[0] == "build":
    sys.stdin.read()
    failure = os.environ.get("CONTAINER_TEST_BUILD_FAIL", "")
    if failure and failure in " ".join(args):
        sys.exit(7)
if args[0] == "run":
    failure = os.environ.get("CONTAINER_TEST_FAIL", "")
    if failure and failure in " ".join(args):
        sys.exit(int(os.environ.get("CONTAINER_TEST_STATUS", "9")))
""")
        docker.chmod(0o755)
        self.log = self.root / "commands.jsonl"
        self.env = dict(
            os.environ, PATH=f"{tools}:{os.environ['PATH']}", CONTAINER_TEST_LOG=str(self.log),
        )
        self.env.pop("CONTAINER_IMAGES", None)

    def archive(self, name):
        archive = self.artifacts / name
        archive.write_bytes(b"compiler")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        Path(str(archive) + ".sha256").write_text(f"{digest}  {name}\n")
        return archive

    def run_script(self, *args, **env):
        return subprocess.run(
            ["/bin/bash", str(self.script), *map(str, args)],
            env=dict(self.env, **env), capture_output=True, text=True, timeout=30,
        )

    def calls(self, command):
        return [
            args for args in map(json.loads, self.log.read_text().splitlines())
            if args[0] == command
        ]

    def test_all_selects_x86_64_archives_and_continues_after_compiler_failure(self):
        bad = self.archive("bad--linux_x86_64.tar.xz")
        good = self.archive("good with spaces--linux_x86_64.tar.xz")
        skipped = self.archive("compiler--linux_aarch64.tar.xz")
        result = self.run_script("all", self.artifacts, CONTAINER_TEST_FAIL=bad.name)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        for guest in ("ubuntu-22.04", "ubuntu-24.04", "alpine-3.24"):
            self.assertIn(f"FAIL\t{guest}\t{bad.name}", result.stdout)
            self.assertIn(f"PASS\t{guest}\t{good.name}", result.stdout)
        self.assertIn(f"SKIP {skipped.name}", result.stdout)
        self.assertEqual(len(self.calls("build")), 3)
        runs = self.calls("run")
        self.assertEqual(len(runs), 6)
        self.assertEqual(len(self.calls("rm")), 6)
        for run in runs:
            self.assertIn("--rm", run)
            self.assertEqual(run[run.index("--platform") + 1], "linux/amd64")
            self.assertEqual(run[run.index("--network") + 1], "none")
            self.assertIn(f"type=bind,source={self.artifacts},target=/archives,readonly", run)
            self.assertIn(f"type=bind,source={self.root}/scripts,target=/scripts,readonly", run)
            self.assertIn("/scripts/toolchain-guest.sh", run)
            self.assertIn("/scripts/smoketest/main.cpp", run)
            self.assertEqual(run[-1], "x86_64")
        results = next((self.root / "o/container-tests").glob("run-*/results.tsv"))
        self.assertEqual(len(results.read_text().splitlines()), 6)

    def test_single_archive_and_full_image_override(self):
        archive = self.archive("compiler with spaces--linux_x86_64.tar.xz")
        image = "registry.example.com/testing/alpine:3.24"
        result = self.run_script(archive, CONTAINER_IMAGES=image)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"PASS\talpine-3.24\t{archive.name}", result.stdout)
        builds = self.calls("build")
        self.assertEqual(len(builds), 1)
        self.assertIn(f"BASE={image}", builds[0])
        self.assertEqual(builds[0][builds[0].index("--platform") + 1], "linux/amd64")
        self.assertEqual(len(self.calls("run")), 1)

    def test_bad_checksums_and_incompatible_selections_do_not_use_docker(self):
        archive = self.archive("compiler--linux_x86_64.tar.xz")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        for sidecar in (
            f"{digest}  wrong-name.tar.xz\n",
            f"{digest}  {archive.name}\n\n",
            f"{'0' * 64}  {archive.name}\n",
        ):
            Path(str(archive) + ".sha256").write_text(sidecar)
            self.assertNotEqual(self.run_script(archive).returncode, 0)
            self.assertFalse(self.log.exists())
        archive.unlink()
        for name in ("compiler--linux_aarch64.tar.xz", "compiler--darwin_arm.tar.xz"):
            incompatible = self.archive(name)
            self.assertNotEqual(self.run_script(incompatible).returncode, 0)
            self.assertFalse(self.log.exists())
        result = self.run_script("all", self.artifacts)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No compatible", result.stderr)
        self.assertFalse(self.log.exists())

    def test_image_preparation_failure_does_not_skip_other_images(self):
        archive = self.archive("compiler--linux_x86_64.tar.xz")
        result = self.run_script(archive, CONTAINER_TEST_BUILD_FAIL="ubuntu:22.04")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("FAIL\tubuntu-22.04\tSee image logs", result.stdout)
        self.assertIn(f"PASS\tubuntu-24.04\t{archive.name}", result.stdout)
        self.assertIn(f"PASS\talpine-3.24\t{archive.name}", result.stdout)
        self.assertEqual(len(self.calls("run")), 2)

    def test_timed_out_container_is_removed(self):
        archive = self.archive("compiler--linux_x86_64.tar.xz")
        result = self.run_script(
            archive, CONTAINER_IMAGES="docker.io/library/ubuntu:22.04",
            CONTAINER_TEST_FAIL=archive.name, CONTAINER_TEST_STATUS="124",
        )
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        run = self.calls("run")[0]
        name = run[run.index("--name") + 1]
        self.assertEqual(self.calls("rm"), [["rm", "--force", name]])


if __name__ == "__main__":
    unittest.main()
