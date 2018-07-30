#!/usr/bin/env bash

# Example
#
# archive.sh /path/to/build_dir /path/to/artifact.tar.xz


set -e

WORK_DIR=$1
TARBALL_PATH=$2

GCC_INSTALL_DIR=$WORK_DIR/x-tools

BUILD_OS=$(uname -s)

if [[ $BUILD_OS = "Darwin" ]]; then
    # Use GNU tar from Homebrew (brew install gnu-tar)
    TAR=gtar
else
    TAR=tar
fi

gcc_tuple()
{
    # Figure out the target's tuple. It's the name of the only directory.
    # Don't call this until after build_gcc()
    tuplepath=$(ls $GCC_INSTALL_DIR)
    if [[ -e $tuplepath ]]; then
        echo "unknown"
    else
        echo $(basename $tuplepath)
    fi
}

echo Building archive...

# Assemble the tarball for the toolchain
TARGET_TUPLE=$(gcc_tuple)
TAR_PATH="${TARBALL_PATH/.xz/}"
TOOLCHAIN_BASE_NAME=$(basename $TARBALL_PATH .tar.xz)

rm -f $TARBALL_PATH $TAR_PATH
mv $GCC_INSTALL_DIR/$TARGET_TUPLE $GCC_INSTALL_DIR/$TOOLCHAIN_BASE_NAME
$TAR c -C $GCC_INSTALL_DIR -f $TAR_PATH $TOOLCHAIN_BASE_NAME
mv $GCC_INSTALL_DIR/$TOOLCHAIN_BASE_NAME $GCC_INSTALL_DIR/$TARGET_TUPLE

echo Compressing archive...
xz $TAR_PATH
