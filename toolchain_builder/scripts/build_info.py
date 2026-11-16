#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys


def command(*args):
    result = subprocess.run(args, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def main():
    builder, install, config, host, ctng = sys.argv[1:]
    builder, install = Path(builder), Path(install)
    recipe = install / "share" / "toolchain-builder"
    recipe.mkdir(parents=True, exist_ok=True)
    files = [builder / name for name in ("VERSION", "Makefile", "LICENSE", "README.md")]
    for pattern in ("*.exs", "scripts/*", "configs/*", "defaults/*", "patches/**/*"):
        files.extend(path for path in builder.glob(pattern) if path.is_file())
    checksums = {}
    for path in sorted(files):
        relative = path.relative_to(builder)
        checksums[str(relative)] = hashlib.sha256(path.read_bytes()).hexdigest()
        destination = recipe / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, destination)

    cc = "gcc-15" if sys.platform == "darwin" else "cc"
    info = {
        "builder_version": (builder / "VERSION").read_text().strip(),
        "builder_commit": command("git", "-C", str(builder), "rev-parse", "HEAD"),
        "builder_status": command(
            "git", "-C", str(builder), "status", "--porcelain", "--untracked-files=normal", "."
        ),
        "recipe_sha256": checksums,
        "configuration": config,
        "host": host,
        "crosstool_ng_commit": ctng,
        "build_platform": platform.platform(),
        "build_compiler": command(cc, "--version"),
        "macos_sdk": command("xcrun", "--show-sdk-version") if sys.platform == "darwin" else None,
    }
    (recipe / "build-info.json").write_text(json.dumps(info, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
