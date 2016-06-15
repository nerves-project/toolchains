#!/bin/sh

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Going to build version '$(git describe --dirty)'. Hit CTRL-C to stop..."
sleep 2

CONFIGS="glibc-eabihf \
         glibc-eabihf-armv6 \
         glibc-i586 \
         glibc-eabi \
         musl-eabihf \
         musl-mipsel_24kec"

for CONFIG in $CONFIGS; do
    echo "Starting build for $CONFIG..."
    ./build.sh $CONFIG
done

echo "All done!!!!!!"

