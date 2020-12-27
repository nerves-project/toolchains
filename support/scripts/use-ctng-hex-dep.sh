#!/bin/bash

set -e

. ./support/scripts/all-configs.sh

BUILD_OS=$(uname -s)
if [[ $BUILD_OS = "Darwin" ]]; then
    SED=gsed
else
    SED=sed
fi

for CONFIG in $CONFIGS; do
    echo "Updating deps for $CONFIG..."
    cd $CONFIG
    $SED -ri 's/nerves_toolchain_ctng, path: "..\/nerves_toolchain_ctng"/nerves_toolchain_ctng, "~> 1.8.0"/' mix.exs
    rm mix.lock
    mix deps.update --all
    cd ../
done
