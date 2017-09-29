#!/usr/bin/env sh

# Give me a chance to hit CTRL-C in case I'm building a -dirty by accident
echo "Building a release of all toolchains listed in $0."
echo "git describe: '$(git describe --dirty)'."
echo "Hit CTRL-C to stop..."
sleep 2

CONFIGS="\
    nerves_toolchain_x86_64_nerves_linux_musl \
    nerves_toolchain_aarch64_nerves_linux_gnueabi \
    nerves_toolchain_arm_nerves_linux_gnueabihf \
    nerves_toolchain_armv5tejl_nerves_linux_musleabi \
    nerves_toolchain_armv6_rpi_linux_gnueabi \
    nerves_toolchain_i586_nerves_linux_gnu \
    nerves_toolchain_mipsel_nerves_linux_musl"

for CONFIG in $CONFIGS; do
    echo "Starting build for $CONFIG..."
    ./nerves_toolchain_ctng/build.sh $CONFIG
done

echo "All done!!!!!!"


