#!/usr/bin/env sh

# Load in all of the configs
. ./support/scripts/all-configs.sh

echo "Building a release of the following toolchain:"
for CONFIG in $CONFIGS; do
    echo "  $CONFIG"
done

echo
echo "git describe: '$(git describe --dirty)'."
echo

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Hit CTRL-C to stop..."
sleep 2

for CONFIG in $CONFIGS; do
    echo "Building $CONFIG..."
    # ./nerves_toolchain_ctng/build.sh $CONFIG
    cd $CONFIG
    mix deps.get
    mix nerves.artifact --path ../
    cd ../
done

echo "All done!!!!!!"


