#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -e

echo
echo "git describe: '$(git describe --dirty)'."
echo

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Hit CTRL-C to stop..."
sleep 2


# Validate pinned component versions without generating Mix packages.
make refresh_version_info

for CONFIG in toolchain_builder/configs/*.defconfig; do
    echo "Building $CONFIG..."
    ./build_one.sh "$(basename "$CONFIG" .defconfig)"
done

echo "All done!!!!!!"


