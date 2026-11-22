#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS=$(uname -s)
ARCH=$(uname -m)
case "$OS:$ARCH" in
    Darwin:arm64|Darwin:x86_64|Linux:x86_64) ;;
    *)
        echo "Unsupported build host: $OS/$ARCH (requires arm64/x86_64 macOS or x86_64 Linux)" >&2
        exit 1
        ;;
esac

for config in "$ROOT"/configs/*.defconfig; do
    config=$(basename "$config" .defconfig)
    if [[ $config = *--mingw_x86_64 ]]; then
        bash "$ROOT/build_with_docker.sh" "$config"
    elif [[ $OS = Darwin && $ARCH = arm64 ]]; then
        bash "$ROOT/build_with_tart.sh" macos "$config"
        bash "$ROOT/build_with_tart.sh" linux "$config"
    elif [[ $OS = Darwin ]]; then
        bash "$ROOT/build_native.sh" "$config"
    else
        bash "$ROOT/build_with_docker.sh" "$config"
    fi
done
