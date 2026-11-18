#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE=$1
OUTPUT=$2
(cd "$(dirname "$ARCHIVE")" && sha256sum -- "$(basename "$ARCHIVE")" | \
    cmp - "$(basename "$ARCHIVE").sha256")
mkdir -p "$ROOT/o/tmp"
export TMPDIR="$ROOT/o/tmp"
WORK=$(mktemp -d "$TMPDIR/smoketest.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

if [[ $(uname -s) = Darwin ]]; then TAR=gtar; else TAR=tar; fi
"$TAR" -xJf "$ARCHIVE" --strip-components=1 -C "$WORK"
compilers=("$WORK"/bin/*-g++)
if [[ ${#compilers[@]} != 1 || ! -x "${compilers[0]}" ]]; then
    echo "Expected one relocatable cross-g++ in the archive" >&2
    exit 1
fi
"${compilers[0]}" -O2 -g0 -Wl,--build-id=none "$ROOT/test/smoketest/main.cpp" -o "$OUTPUT"
