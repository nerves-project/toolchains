#!/bin/sh

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Going to build version '$(git describe --dirty)'. Hit CTRL-C to stop..."
sleep 2

HOST_OS=$(uname -s)

CONFIGS="$HOST_OS-glibc-eabihf \
         $HOST_OS-glibc-eabihf-armv6"

# Comment out musl support since it doesn't build on OSX
#         $HOST_OS-musl-eabihf-armv6"

for CONFIG in $CONFIGS; do
    echo "Starting build for $CONFIG..."
    ./build.sh $CONFIG
done

echo "All done!!!!!!"

