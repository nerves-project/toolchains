#!/bin/bash

set -e

. ./support/scripts/all-configs.sh

for CONFIG in $CONFIGS; do
    echo "Pushing $CONFIG to hex"
    cd $CONFIG
    mix deps.get
    mix hex.publish package --yes
    cd ../
done
