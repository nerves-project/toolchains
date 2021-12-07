#!/usr/bin/env bash

set -e

. ./support/scripts/all-configs.sh

for CONFIG in $CONFIGS; do
    echo "Cleaning $CONFIG..."
    cd $CONFIG
    rm -rf _build deps .nerves
    cd ../
done
