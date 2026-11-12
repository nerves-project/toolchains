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
    echo "package.sh <installed toolchain directory> <output directory> <package name> <legacy host tuple>" >&2
    exit 1
fi

ARTIFACT_NAMES=$(elixir "$BUILDER_DIR/artifact_names.exs" "$TOOLCHAIN" "$HOST")
read -r NATIVE_ARCHIVE COMPAT_ARCHIVE <<< "$ARTIFACT_NAMES"
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

mv "$INSTALL_DIR" "$STAGING_DIR"
trap 'mv "$STAGING_DIR" "$INSTALL_DIR"' EXIT
"$TAR" -c -J -C "$PARENT_DIR" -f "$OUTPUT_DIR/$NATIVE_ARCHIVE" "$RELEASE_NAME"
cp "$OUTPUT_DIR/$NATIVE_ARCHIVE" "$OUTPUT_DIR/$COMPAT_ARCHIVE"
echo "Native archive: $OUTPUT_DIR/$NATIVE_ARCHIVE"
echo "Nerves 1 compatibility archive: $OUTPUT_DIR/$COMPAT_ARCHIVE"
