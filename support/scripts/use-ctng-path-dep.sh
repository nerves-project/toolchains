#!/usr/bin/env bash

set -e

. ./support/scripts/all-configs.sh

BUILD_OS=$(uname -s)
if [[ $BUILD_OS = "Darwin" || $BUILD_OS = "darwin" ]]; then
    SED=gsed
else
    SED=sed
fi

for CONFIG in $CONFIGS; do
    echo "Updating deps for $CONFIG..."
    cd $CONFIG
    $SED -ri 's/nerves_toolchain_ctng, ".*[0-9]+.[0-9]+.[0-9]+"/nerves_toolchain_ctng, path: "..\/nerves_toolchain_ctng"/' mix.exs
    cd ../
done
