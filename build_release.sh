#!/bin/sh

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Going to build version '$(git describe --dirty)'. Hit CTRL-C to stop..."
sleep 2

HOST_OS=$(uname -s)
if [ $HOST_OS = "Darwin" ]; then
    CONFIG_PREFIX="osx"
elif [ $HOST_OS = "Linux" ]; then
    CONFIG_PREFIX="linux"
else
    echo "Unknown host platform: $HOST_OS"
    exit 1
fi

CONFIGS="$CONFIG_PREFIX-glibc-eabihf"

for CONFIG in $CONFIGS; do
    echo "Starting build for $CONFIG..."
    ./build.sh $CONFIG
done

echo "All done!!!!!!"

