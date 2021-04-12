#!/usr/bin/env sh

set -e

# Load in all of the configs
. ./support/scripts/all-configs.sh

echo "Building a release of the following toolchains:"
echo
for CONFIG in $CONFIGS; do
    echo "  $CONFIG"
done

echo
echo "git describe: '$(git describe --dirty)'."
echo

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Hit CTRL-C to stop..."
sleep 2

# Do some basic cleanup to avoid easy mistakes from stale files
find . -name .nerves | xargs rm -fr
find . -name deps | xargs rm -fr
find . -name _build | xargs rm -fr

for CONFIG in $CONFIGS; do
    echo "Building $CONFIG..."
    # ./nerves_toolchain_ctng/build.sh $CONFIG
    cd $CONFIG
    mix deps.get
    mix nerves.artifact --path ../
    echo "Done building $CONFIG"
    # TMP
    echo "df -h:"
    df -h
    cd ../
done

echo "All done!!!!!!"


