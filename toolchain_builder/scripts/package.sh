#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# != 4 ]]; then
    echo "package.sh <installed toolchain directory> <output directory> <config name> <host>" >&2
    exit 1
fi

INSTALL_DIR=$1
OUTPUT_DIR=$2
TOOLCHAIN=$3
HOST=$4

if [[ ! -d "$INSTALL_DIR/bin" ]]; then
    echo "package.sh <installed toolchain directory> <output directory> <config name> <host>" >&2
    exit 1
fi

NATIVE_ARCHIVE=$(elixir "$BUILDER_DIR/artifact_names.exs" "$TOOLCHAIN" "$HOST")
RELEASE_NAME=${NATIVE_ARCHIVE%--*}
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
PARENT_DIR=$(dirname "$INSTALL_DIR")
STAGING_DIR="$PARENT_DIR/$RELEASE_NAME"

TAR=tar
if [[ $(uname -s) = Darwin ]]; then
    TAR=gtar
fi

if [[ -e "$STAGING_DIR" ]]; then
    echo "Staging directory already exists: $STAGING_DIR" >&2
    exit 1
fi

if [[ -e "$OUTPUT_DIR/$NATIVE_ARCHIVE" || -e "$OUTPUT_DIR/$NATIVE_ARCHIVE.sha256" ]]; then
    echo "Archive already exists: $OUTPUT_DIR/$NATIVE_ARCHIVE. Use a new release version or output directory." >&2
    exit 1
fi

TMP_DIR=$(mktemp -d "$OUTPUT_DIR/.toolchain.XXXXXX")
cleanup()
{
    mv "$STAGING_DIR" "$INSTALL_DIR"
    rm -f "$TMP_DIR/$NATIVE_ARCHIVE" "$TMP_DIR/$NATIVE_ARCHIVE.sha256"
    rmdir "$TMP_DIR"
}
mv "$INSTALL_DIR" "$STAGING_DIR"
trap cleanup EXIT
"$TAR" -c -C "$PARENT_DIR" -f - "$RELEASE_NAME" | zstd -T0 -q -o "$TMP_DIR/$NATIVE_ARCHIVE"
python3 "$BUILDER_DIR/scripts/artifact.py" checksum "$TMP_DIR/$NATIVE_ARCHIVE" > "$TMP_DIR/$NATIVE_ARCHIVE.sha256"
ln "$TMP_DIR/$NATIVE_ARCHIVE" "$OUTPUT_DIR/$NATIVE_ARCHIVE"
ln "$TMP_DIR/$NATIVE_ARCHIVE.sha256" "$OUTPUT_DIR/$NATIVE_ARCHIVE.sha256"
echo "Native archive: $OUTPUT_DIR/$NATIVE_ARCHIVE"
echo "SHA256: $OUTPUT_DIR/$NATIVE_ARCHIVE.sha256"
