# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


BUILD = Path(__file__).resolve().parents[1] / "build_native.sh"
class BuildDiskImageTest(unittest.TestCase):
    def test_exit_removes_image_unless_debug_is_set_or_unmount_fails(self):
        source = BUILD.read_text()
        functions = source[:source.index("\ntrap cleanup EXIT")]
        for status, debug, eject_status in [
            (0, None, 0), (23, None, 0), (0, "", 0), (0, "1", 0), (0, None, 1)
        ]:
            with self.subTest(status=status, debug=debug, eject_status=eject_status):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    mount = root / "mount"
                    mount.mkdir()
                    work = root / "work"
                    work.symlink_to(mount)
                    image = root / "work.dmg"
                    image.write_text("image")
                    env = dict(os.environ, SCRIPT_DIR=directory, WORK_DIR=str(work),
                               WORK_DMG=str(image), WORK_DMG_CREATED="true",
                               WORK_DMG_DEVICE="/dev/disk99", WORK_DMG_VOLNAME="test",
                               TEST_STATUS=str(status), EJECT_STATUS=str(eject_status))
                    env.pop("DEBUG", None)
                    if debug is not None:
                        env["DEBUG"] = debug
                    result = subprocess.run(["bash", "-c", functions + """
diskutil() { echo "$*" > "$SCRIPT_DIR/ejected"; return "$EJECT_STATUS"; }
cd "$WORK_DIR"
trap cleanup EXIT
exit "$TEST_STATUS"
"""], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, status or eject_status, result.stderr)
                    self.assertEqual(image.exists(), debug is not None or eject_status != 0)
                    self.assertEqual(work.is_symlink(), image.exists())
                    self.assertEqual((root / "ejected").exists(), debug is None)

    def run_init(self, image_api, filesystem_option):
        source = BUILD.read_text()
        init = source[source.index("\ninit()\n"):source.index("\nbuild_gcc()\n")]
        with tempfile.TemporaryDirectory(prefix="toolchain-image-") as directory:
            root = Path(directory)
            script = """
set -e
diskutil() {
    printf 'diskutil %s\\n' "$*" >> "$COMMAND_LOG"
    if [[ $* = "image create blank --help" ]]; then
        if [[ $IMAGE_API != yes ]]; then return 1; fi
        echo 'Usage: diskutil image create blank --size <size> <image-path>'
        if [[ $FILESYSTEM_OPTION = yes ]]; then echo '  --fs <fs>'; fi
        return 0
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
                IMAGE_API="yes" if image_api else "no",
                FILESYSTEM_OPTION="yes" if filesystem_option else "no",
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
        commands, image = self.run_init(image_api=True, filesystem_option=True)
        self.assertIn(f"diskutil image create blank --size 32g --fs None {image}", commands)
        self.assertIn(f"diskutil image attach --noMount {image}", commands)
        self.assertIn("diskutil eraseDisk HFSX test-volume /dev/disk99", commands)
        self.assertFalse(any(command.startswith("hdiutil ") for command in commands))

    def test_older_macos_uses_hdiutil_for_image_creation_and_attachment(self):
        for image_api in [False, True]:
            with self.subTest(image_api=image_api):
                commands, image = self.run_init(image_api=image_api, filesystem_option=False)
                self.assertIn(
                    f"hdiutil create -size 32g -fs Case-sensitive HFS+ -volname test-volume {image}",
                    commands,
                )
                self.assertIn(f"hdiutil attach {image}", commands)
                self.assertFalse(any("eraseDisk" in command for command in commands))


class BuildProcessTest(unittest.TestCase):
    def test_installed_target_requires_exactly_one_compiler(self):
        source = BUILD.read_text()
        post_build = source.split("    $CTNG $CTNG_BUILD\n", 1)[1]
        post_build = post_build[:post_build.index("\nsave_build_info()\n")]
        script = "set -e\nfinish_build() {\n" + post_build + """
finish_build
printf '%s\\n' "$TARGET_TUPLE" "$INSTALL_DIR"
"""
        target = "x86_64-nerves-linux-gnu"
        for count in [0, 1, 2]:
            with self.subTest(compilers=count), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / "x tools"
                root.mkdir()
                for index in range(count):
                    install = root / f"install{index}"
                    (install / "bin").mkdir(parents=True)
                    (install / "bin" / f"{target}-gcc").touch()
                    (install / "build.log.bz2").touch()
                env = dict(os.environ, GCC_INSTALL_DIR=str(root))
                result = subprocess.run(
                    ["bash", "-c", script], env=env, capture_output=True, text=True
                )
                if count == 1:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(
                        result.stdout.splitlines()[-2:], [target, str(root / "install0")]
                    )
                    self.assertFalse((root / "install0/build.log.bz2").exists())
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Expected exactly one installed", result.stderr)

    def test_completed_archive_skips_build_without_touching_work_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copyfile(BUILD, root / "build_native.sh")
            for name in ["configs", "scripts"]:
                (root / name).symlink_to(BUILD.parent / name, target_is_directory=True)
            for name in ["VERSION"]:
                (root / name).symlink_to(BUILD.parent / name)
            artifacts = root / "o/artifacts"
            artifacts.mkdir(parents=True)
            target = "x86_64-nerves-linux-gnu"
            release = (root / "VERSION").read_text().strip()
            archive = artifacts / (
                f"{target}--gcc-15.3.0-glibc-2.43-linux-6.1.175--{release}"
                "--linux_x86_64.tar.xz"
            )
            archive.write_bytes(b"completed archive")
            checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
            Path(str(archive) + ".sha256").write_text(f"{checksum}  {archive.name}\n")
            work = root / "o" / f"{target}--gcc15"
            work.mkdir()
            marker = work / "preserve"
            marker.write_text("build data")
            env = dict(os.environ, HOST_OS="linux", HOST_ARCH="x86_64")
            command = ["bash", str(root / "build_native.sh"), f"{target}--gcc15"]
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Skipping", result.stdout)
            self.assertEqual(marker.read_text(), "build data")
            archive.write_bytes(b"corrupt")
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("Skipping", result.stdout)
            self.assertTrue(marker.exists())


class BuildAllTest(unittest.TestCase):
    def setUp(self):
        root = BUILD.parent
        (root / "o/tmp").mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="build-all-test-", dir=root / "o/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.script = self.root / "build_all.sh"
        shutil.copyfile(root / "build_all.sh", self.script)
        configs = self.root / "configs"
        configs.mkdir()
        self.configs = ["armv7-nerves-linux-gnueabihf--gcc15", "x86_64-nerves-linux-gnu--gcc16"]
        for config in self.configs:
            (configs / f"{config}.defconfig").touch()
        tools = self.root / "tools"
        tools.mkdir()
        uname = tools / "uname"
        uname.write_text(
            '#!/bin/sh\nif [ "$1" = -s ]; then echo "$BUILD_ALL_TEST_OS"; '
            'else echo "$BUILD_ALL_TEST_ARCH"; fi\n'
        )
        uname.chmod(0o755)
        for kind, script in (
            ("tart", "build_with_tart.sh"),
            ("docker", "build_with_docker.sh"),
            ("native", "build_native.sh"),
        ):
            (self.root / script).write_text(
                f'printf "%s\\n" "{kind} $*" >> "$BUILD_ALL_TEST_LOG"\n'
                'exit "${BUILD_ALL_TEST_STATUS:-0}"\n'
            )
        self.log = self.root / "commands.log"
        self.env = dict(
            os.environ, PATH=f"{tools}:{os.environ['PATH']}", BUILD_ALL_TEST_LOG=str(self.log),
        )

    def run_script(self, os_name, arch, **env):
        return subprocess.run(
            ["/bin/bash", str(self.script)],
            env=dict(self.env, BUILD_ALL_TEST_OS=os_name, BUILD_ALL_TEST_ARCH=arch, **env),
            capture_output=True, text=True, timeout=30,
        )

    def test_dispatches_all_configs_to_platform_wrappers(self):
        for os_name, arch, commands in (
            ("Darwin", "arm64", ["tart macos", "tart linux"]),
            ("Darwin", "x86_64", ["native"]),
            ("Linux", "x86_64", ["docker"]),
        ):
            with self.subTest(os=os_name, arch=arch):
                result = self.run_script(os_name, arch)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    self.log.read_text().splitlines(),
                    [f"{command} {config}" for config in self.configs for command in commands],
                )
                self.log.unlink()

    def test_rejects_unsupported_hosts_without_building(self):
        for os_name, arch in (("Linux", "aarch64"), ("Darwin", "i386"), ("FreeBSD", "amd64")):
            with self.subTest(os=os_name, arch=arch):
                result = self.run_script(os_name, arch)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Unsupported build host", result.stderr)
                self.assertFalse(self.log.exists())

    def test_build_failure_stops_remaining_builds_and_preserves_status(self):
        for os_name, arch in (("Darwin", "arm64"), ("Darwin", "x86_64"), ("Linux", "x86_64")):
            with self.subTest(os=os_name):
                result = self.run_script(os_name, arch, BUILD_ALL_TEST_STATUS="23")
                self.assertEqual(result.returncode, 23, result.stderr)
                self.assertEqual(len(self.log.read_text().splitlines()), 1)
                self.log.unlink()


if __name__ == "__main__":
    unittest.main()
