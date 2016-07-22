#!/bin/sh

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Building a release of all toolchains listed in $0."
echo "Version '$(git describe --dirty)'."
echo "Hit CTRL-C to stop..."
sleep 2

CONFIGS="glibc-eabihf \
         glibc-eabihf-armv6 \
         glibc-i586 \
         glibc-eabi \
         musl-eabihf \
         musl-mipsel_24kec"

CONFIGS="nerves_toolchain_armv5tejl_unknown_linux_gnueabi"

for CONFIG in $CONFIGS; do
    echo "Starting build for $CONFIG..."
    ./nerves_toolchain_ctng/build.sh $CONFIG
done

echo "All done!!!!!!"

