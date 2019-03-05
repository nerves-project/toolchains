#!/bin/bash

set -e

. ./support/scripts/all-configs.sh

for CONFIG in $CONFIGS; do
    echo "Updating deps for $CONFIG..."
    cd $CONFIG
    sed -ri 's/nerves_toolchain_ctng, "~> 1.5.0"/nerves_toolchain_ctng, path: "..\/nerves_toolchain_ctng"/' mix.exs
    cd ../
done
