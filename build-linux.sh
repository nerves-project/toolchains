#!/bin/sh

set -e

CTNG_TAG=625f7e66b43c8629c7ca27b062ff7adad9c2b859
BASE_DIR=`pwd`
WORK_DIR=$BASE_DIR/work

NERVES_TOOLCHAIN_TAG=`git describe --always --dirty`
HOST_ARCH=`uname -m`

# Clean up an old build
chmod -R u+w $WORK_DIR
rm -fr $WORK_DIR

mkdir -p $WORK_DIR
mkdir -p $WORK_DIR/usr

# Build and install ct-ng to the work directory
cd $WORK_DIR
git clone https://github.com/crosstool-ng/crosstool-ng.git
cd crosstool-ng
git checkout $CTNG_TAG

./bootstrap
echo ./configure --prefix=$WORK_DIR/usr
./configure --prefix=$WORK_DIR/usr
make
make install

# Build the toolchain
mkdir -p $WORK_DIR/build
cd $WORK_DIR/build
cp $BASE_DIR/configs/linux.config .config
$WORK_DIR/usr/bin/ct-ng build

# Figure out the target's tuple. It's the name of the only directory.
cd $WORK_DIR/x-tools
TARGET_TUPLE=`ls`

# Clean up the build product
rm -f $TARGET_TUPLE/build.log.bz2

# Assemble the tarball for the toolchain
echo "$NERVES_TOOLCHAIN_TAG" > $TARGET_TUPLE/nerves-toolchain.tag
tar cfz ../../gcc-nerves-$TARGET_TUPLE-linux-$HOST_ARCH-$NERVES_TOOLCHAIN_TAG.tgz $TARGET_TUPLE
