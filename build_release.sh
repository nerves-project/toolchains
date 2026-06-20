#!/usr/bin/env bash

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


CONFIGS=$(find . -name "nerves_toolchain*")

for CONFIG in $CONFIGS; do
    echo "Building $CONFIG..."
    $CONFIG/build.sh o/$CONFIG ..
done

echo "All done!!!!!!"


