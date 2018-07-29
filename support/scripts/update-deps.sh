#!/bin/bash

set -e

. ./support/scripts/all-configs.sh

for CONFIG in $CONFIGS; do
    echo "Updating deps for $CONFIG..."
    cd $CONFIG
    mix deps.update --all
    cd ../
done
