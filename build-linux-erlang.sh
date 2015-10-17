#!/bin/sh

set -e

# Temporary script (merge into or call from build-linux)

ERLANG_VERSION=18.1
BASE_DIR=`pwd`
WORK_DIR=$BASE_DIR/work

INSTALL_NAME=nerves-erlang
INSTALL_DIR=$WORK_DIR/$INSTALL_NAME

NERVES_TOOLCHAIN_TAG=`git describe --always --dirty`
HOST_ARCH=`uname -m`

# Create directories and clean them up if there was a previous build
mkdir -p $WORK_DIR
rm -fr $WORK_DIR/nerves-erlang
rm -fr $WORK_DIR/otp_src_$ERLANG_VERSION
mkdir -p $WORK_DIR/nerves-erlang

# Build and install ct-ng to the work directory
cd $WORK_DIR
wget http://www.erlang.org/download/otp_src_$ERLANG_VERSION.tar.gz
tar xf otp_src_$ERLANG_VERSION.tar.gz
cd otp_src_$ERLANG_VERSION

./configure --prefix=$INSTALL_DIR --disable-hipe
make
make install

# Assemble the tarball for the toolchain
cd $WORK_DIR
echo "$NERVES_TOOLCHAIN_TAG" > $INSTALL_DIR/nerves-toolchain.tag
tar cfz ../nerves-erlang-$ERLANG_VERSION-linux-$HOST_ARCH.tgz $INSTALL_NAME

echo Done!
