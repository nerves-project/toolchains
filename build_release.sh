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


# Do some basic cleanup to avoid easy mistakes from stale files
make clean

# Regenerate packages
make


CONFIGS=$(find toolchain_builder/configs -mindepth 1 -maxdepth 1 -type d -name 'nerves_toolchain_*')

for CONFIG in $CONFIGS; do
    echo "Building $CONFIG..."
    ./build_one.sh "$(basename "$CONFIG")"
done

echo "All done!!!!!!"


