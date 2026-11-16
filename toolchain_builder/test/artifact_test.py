# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("artifact", ROOT / "scripts/artifact.py")
artifact = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifact)


class ArtifactTest(unittest.TestCase):
    def test_checksum_rejects_changed_archive_and_wrong_filename(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "compiler.tar.zst"
            path.write_bytes(b"compiler")
            sidecar = Path(str(path) + ".sha256")
            contents = artifact.checksum_line(path)
            sidecar.write_text(contents)
            artifact.verify(path)
            path.write_bytes(b"different compiler")
            with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
                artifact.verify(path)
            sidecar.write_text(contents.replace(path.name, "another.tar.zst"))
            with self.assertRaisesRegex(ValueError, "Invalid checksum file"):
                artifact.verify(path)

    def test_publishing_checks_all_pairs_and_uploads_checksums_last_without_overwriting(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "compiler.tar.zst"
            archive.write_bytes(b"compiler")
            sidecar = Path(str(archive) + ".sha256")
            sidecar.write_text(artifact.checksum_line(archive))
            log = root / "aws.log"
            aws = root / "aws"
            aws.write_text("#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$AWS_TEST_LOG\"\n")
            aws.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", AWS_TEST_LOG=str(log))
            command = ["bash", str(ROOT / "scripts/publish.sh"), "s3://bucket/toolchains/", str(root)]
            subprocess.run(command, env=env, check=True, capture_output=True)
            calls = log.read_text().splitlines()
            self.assertEqual(len(calls), 2)
            self.assertIn("--key toolchains/compiler.tar.zst --body", calls[0])
            self.assertIn("--key toolchains/compiler.tar.zst.sha256 --body", calls[1])
            self.assertTrue(all("--if-none-match *" in call for call in calls))
            log.unlink()
            archive.write_bytes(b"corrupted")
            result = subprocess.run(command, env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(log.exists())

    def test_build_info_preserves_the_recipe_without_requiring_git(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            install = root / "installed"
            install.mkdir()
            subprocess.run([
                "python3", str(ROOT / "scripts/build_info.py"), str(ROOT), str(install),
                "armv7-nerves-linux-gnueabihf--gcc15", "linux_x86_64", "ctng-commit",
            ], check=True)
            recipe = install / "share/toolchain-builder"
            info = json.loads((recipe / "build-info.json").read_text())
            self.assertEqual(info["crosstool_ng_commit"], "ctng-commit")
            self.assertEqual(
                (recipe / "configs/armv7-nerves-linux-gnueabihf--gcc15.defconfig").read_bytes(),
                (ROOT / "configs/armv7-nerves-linux-gnueabihf--gcc15.defconfig").read_bytes(),
            )
            self.assertIn("scripts/package.sh", info["recipe_sha256"])
            self.assertIn("crosstool_ng.exs", info["recipe_sha256"])

    def test_publishing_can_resume_but_rejects_changed_remote_objects(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "compiler.tar.zst"
            archive.write_bytes(b"compiler")
            Path(str(archive) + ".sha256").write_text(artifact.checksum_line(archive))
            remote = root / "remote"
            remote.mkdir()
            aws = root / "aws"
            aws.write_text(
                "#!/usr/bin/env python3\n"
                "import base64, hashlib, os, pathlib, shutil, sys\n"
                "args = sys.argv[1:]\n"
                "key = pathlib.Path(os.environ['AWS_TEST_REMOTE']) / pathlib.Path(args[args.index('--key') + 1]).name\n"
                "if args[1] == 'put-object':\n"
                "    if key.exists(): sys.exit(1)\n"
                "    shutil.copyfile(args[args.index('--body') + 1], key)\n"
                "else:\n"
                "    print(base64.b64encode(hashlib.sha256(key.read_bytes()).digest()).decode())\n"
            )
            aws.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", AWS_TEST_REMOTE=str(remote))
            command = ["bash", str(ROOT / "scripts/publish.sh"), "s3://bucket/toolchains/", str(root)]
            for _ in range(2):
                subprocess.run(command, env=env, capture_output=True, check=True)
            remote_archive = remote / archive.name
            remote_archive.write_bytes(b"conflicting remote compiler")
            result = subprocess.run(command, env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(remote_archive.read_bytes(), b"conflicting remote compiler")


if __name__ == "__main__":
    unittest.main()
