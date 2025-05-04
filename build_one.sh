#!/bin/sh

TOOLCHAIN=$1

if [ -z $TOOLCHAIN ]; then
	echo "Pass a toolchain directory name (e.g., nerves_toolchain_armv7_nerves_linux_gnueabihf)"
	exit 1
fi

./nerves_toolchain_ctng/build.sh $TOOLCHAIN/defconfig $PWD/o/$TOOLCHAIN

