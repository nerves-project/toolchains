#!/bin/bash

set -e

NEW_VERSION=$1

if [[ -z "$NEW_VERSION" ]]; then
    echo "Specify the new version"
    exit 1
fi

. ./support/scripts/all-configs.sh

for CONFIG in $CONFIGS; do
    echo "Updating version for $CONFIG..."
    echo $NEW_VERSION > $CONFIG/VERSION
done
