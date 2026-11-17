#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# != 3 ]]; then
    echo "package.sh <installed toolchain directory> <output directory> <host>" >&2
    exit 1
fi

INSTALL_DIR=$1
OUTPUT_DIR=$2
HOST=$3

if [[ ! -d "$INSTALL_DIR/bin" ]]; then
    echo "package.sh <installed toolchain directory> <output directory> <host>" >&2
    exit 1
fi

elixir "$BUILDER_DIR/scripts/archive.exs" --prepare "$INSTALL_DIR" "$HOST"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
PARENT_DIR=$(dirname "$INSTALL_DIR")
INSTALL_NAME=$(basename "$INSTALL_DIR")

TAR=tar
if [[ $(uname -s) = Darwin ]]; then
    TAR=gtar
fi

TMP_DIR=$(mktemp -d "$OUTPUT_DIR/.toolchain.XXXXXX")
cleanup()
{
    rm -f "$TMP_DIR/archive.tar.xz" "$TMP_DIR/archive.tar.xz.sha256"
    rmdir "$TMP_DIR"
}
trap cleanup EXIT
# Put metadata first so inspection need not decompress the compiler payload.
"$TAR" -c -C "$PARENT_DIR" -f - "$INSTALL_NAME/toolchain-builder.metadata" \
    --exclude="$INSTALL_NAME/toolchain-builder.metadata" "$INSTALL_NAME" | \
    xz -T0 -6 -c > "$TMP_DIR/archive.tar.xz"
NATIVE_ARCHIVE=$(elixir "$BUILDER_DIR/scripts/archive.exs" --name "$TMP_DIR/archive.tar.xz")

if [[ -e "$OUTPUT_DIR/$NATIVE_ARCHIVE" || -e "$OUTPUT_DIR/$NATIVE_ARCHIVE.sha256" ]]; then
    echo "Archive already exists: $OUTPUT_DIR/$NATIVE_ARCHIVE. Use a new release version or output directory." >&2
    exit 1
fi

if [[ $(uname -s) = Darwin ]]; then
    DIGEST=$(shasum -a 256 "$TMP_DIR/archive.tar.xz")
else
    DIGEST=$(sha256sum "$TMP_DIR/archive.tar.xz")
fi
printf '%s  %s\n' "${DIGEST%% *}" "$NATIVE_ARCHIVE" > "$TMP_DIR/archive.tar.xz.sha256"
ln "$TMP_DIR/archive.tar.xz" "$OUTPUT_DIR/$NATIVE_ARCHIVE"
ln "$TMP_DIR/archive.tar.xz.sha256" "$OUTPUT_DIR/$NATIVE_ARCHIVE.sha256"
echo "Native archive: $OUTPUT_DIR/$NATIVE_ARCHIVE"
echo "SHA256: $OUTPUT_DIR/$NATIVE_ARCHIVE.sha256"
