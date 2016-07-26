#!/bin/sh

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Building a release of all toolchains listed in $0."
echo "git describe: '$(git describe --dirty)'."
echo "Hit CTRL-C to stop..."
sleep 2

# Old configs - to be removed
CONFIGS="glibc-eabihf \
         glibc-eabihf-armv6 \
         glibc-i586 \
         glibc-eabi \
         musl-eabihf \
         musl-mipsel_24kec"

CONFIGS="\
    nerves_toolchain_armv5tejl_unknown_linux_musleabi \
    nerves_toolchain_x86_64_unknown_linux_musl"

for CONFIG in $CONFIGS; do
    echo "Starting build for $CONFIG..."
    ./nerves_toolchain_ctng/build.sh $CONFIG
done

echo "All done!!!!!!"

