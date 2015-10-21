#!/bin/sh

set -e

# Temporary script (merge into or call from build-linux)

ERLANG_VERSION=18.1

HOST_ARCH=`uname -m`

BASE_DIR=`pwd`
WORK_DIR=$BASE_DIR/work

INSTALL_NAME=elixir-nerves-$HOST_ARCH
INSTALL_DIR=$WORK_DIR/$INSTALL_NAME

NERVES_TOOLCHAIN_TAG=`git describe --always --dirty`


# Create directories and clean them up if there was a previous build
mkdir -p $WORK_DIR
rm -fr $WORK_DIR/$INSTALL_NAME
rm -fr $WORK_DIR/otp_src_$ERLANG_VERSION
mkdir -p $WORK_DIR/$INSTALL_NAME

cd $WORK_DIR
# wget http://www.erlang.org/download/otp_src_$ERLANG_VERSION.tar.gz
# tar xf otp_src_$ERLANG_VERSION.tar.gz
cd otp_src_$ERLANG_VERSION
# Link on newer openssl version
# brew link --force openssl
./configure --prefix=$INSTALL_DIR --disable-hipe --with-ssl=/usr/local/bin
make
make install

# Assemble the tarball for the toolchain
cd $WORK_DIR
echo "$NERVES_TOOLCHAIN_TAG" > $INSTALL_DIR/nerves-toolchain.tag
tar cfz ../nerves-erlang-$ERLANG_VERSION-mac-$HOST_ARCH.tgz $INSTALL_NAME

echo Done!
