#!/bin/sh

set -e

CTNG_TAG=625f7e66b43c8629c7ca27b062ff7adad9c2b859
BASE_DIR=`pwd`
WORK_DIR=$BASE_DIR/work
WORK_DMG=$WORK_DIR.dmg
WORK_DMG_VOLNAME=nerves-gcc-build


NERVES_TOOLCHAIN_TAG=`git describe --always --dirty`
HOST_ARCH=`uname -m`

# Make sure that we have enough file handles
ulimit -n 512

# Clean up an old build
hdiutil detach /Volumes/$WORK_DMG_VOLNAME || true
rm -fr $WORK_DIR $WORK_DMG
hdiutil create -size 10g -fs "Case-sensitive Journaled HFS+" -volname $WORK_DMG_VOLNAME $WORK_DMG
hdiutil attach $WORK_DMG
ln -s /Volumes/$WORK_DMG_VOLNAME $WORK_DIR
#
mkdir -p $WORK_DIR/usr
ln -s $BASE_DIR/dl $WORK_DIR/dl
#
# # Build and install ct-ng to the work directory
cd $WORK_DIR
git clone https://github.com/crosstool-ng/crosstool-ng.git
cd crosstool-ng
git checkout $CTNG_TAG
#
./bootstrap
./configure --prefix=$WORK_DIR/usr
make
make install
#
# # Build the toolchain
mkdir -p $WORK_DIR/build
cd $WORK_DIR/build
cp $BASE_DIR/configs/osx.config .config
CC=/usr/local/bin/gcc-5 CXX=/usr/local/bin/c++-5 $WORK_DIR/usr/bin/ct-ng build
#
# # Figure out the target's tuple. It's the name of the only directory.
cd $WORK_DIR/x-tools
TARGET_TUPLE=`ls`
PRODUCT_DMG_VOLNAME=nerves-gcc-$TARGET_TUPLE-osx-$HOST_ARCH-$NERVES_TOOLCHAIN_TAG
PRODUCT_DMG=$BASE_DIR/$PRODUCT_DMG_VOLNAME.dmg

# Clean up the build product
chmod +w $TARGET_TUPLE && rm -f $TARGET_TUPLE/build.log.bz2
# Assemble the tarball for the toolchain
echo "$NERVES_TOOLCHAIN_TAG" > $TARGET_TUPLE/nerves-toolchain.tag
cd $BUILD_DIR

#Create final DMG with compiler tools in it
rm -fr $PRODUCT_DMG
hdiutil create -fs "Case-sensitive Journaled HFS+" -srcFolder $WORK_DIR/x-tools/$TARGET_TUPLE -volname $PRODUCT_DMG_VOLNAME $PRODUCT_DMG
hdiutil detach /Volumes/$WORK_DMG_VOLNAME || true
echo "All Done!"
