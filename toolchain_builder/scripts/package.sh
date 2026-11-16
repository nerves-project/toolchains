#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -e

BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR=$1
OUTPUT_DIR=$2
TOOLCHAIN=$3
HOST=$4

if [[ $# != 4 || ! -d "$INSTALL_DIR/bin" ]]; then
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

if [[ -e "$OUTPUT_DIR/$NATIVE_ARCHIVE" ]]; then
    echo "Archive already exists: $OUTPUT_DIR/$NATIVE_ARCHIVE. Use a new release version or output directory." >&2
    exit 1
fi

mv "$INSTALL_DIR" "$STAGING_DIR"
TMP_ARCHIVE=""
trap 'mv "$STAGING_DIR" "$INSTALL_DIR"; if [[ -n "$TMP_ARCHIVE" ]]; then rm -f "$TMP_ARCHIVE"; fi' EXIT
TMP_ARCHIVE=$(mktemp "$OUTPUT_DIR/.toolchain.XXXXXX")
"$TAR" -c -J -C "$PARENT_DIR" -f "$TMP_ARCHIVE" "$RELEASE_NAME"
ln "$TMP_ARCHIVE" "$OUTPUT_DIR/$NATIVE_ARCHIVE"
echo "Native archive: $OUTPUT_DIR/$NATIVE_ARCHIVE"
