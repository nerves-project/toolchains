CONFIGS="\
    nerves_toolchain_x86_64_unknown_linux_musl \
    nerves_toolchain_aarch64_unknown_linux_gnueabi \
    nerves_toolchain_arm_unknown_linux_gnueabihf \
    nerves_toolchain_armv5tejl_unknown_linux_musleabi \
    nerves_toolchain_armv6_rpi_linux_gnueabi \
    nerves_toolchain_i586_unknown_linux_gnu \
    nerves_toolchain_mipsel_unknown_linux_musl \
    nerves_toolchain_x86_64_unknown_linux_gnu"

for CONFIG in $CONFIGS; do
    echo "Updating deps for $CONFIG..."
    # ./nerves_toolchain_ctng/build.sh $CONFIG
    cd $CONFIG
    mix clean && mix nerves.clean --all
    cd ../
done
