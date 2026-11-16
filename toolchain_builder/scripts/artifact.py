#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

import hashlib
from pathlib import Path
import re
import sys


def digest(path):
    checksum = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            checksum.update(block)
    return checksum.hexdigest()


def checksum_line(path):
    return f"{digest(path)}  {path.name}\n"


def verify(path):
    sidecar = Path(str(path) + ".sha256")
    contents = sidecar.read_text()
    match = re.fullmatch(r"([0-9a-f]{64})  ([^\r\n/]+)\n", contents)
    if not match or match[2] != path.name:
        raise ValueError(f"Invalid checksum file: {sidecar}")
    if match[1] != digest(path):
        raise ValueError(f"Checksum mismatch: {path}")


if __name__ == "__main__":
    operation, filename = sys.argv[1:]
    archive = Path(filename)
    if operation == "checksum":
        print(checksum_line(archive), end="")
    elif operation == "verify":
        verify(archive)
        print(f"Verified {archive.name}")
    else:
        raise SystemExit("artifact.py checksum|verify <archive>")
