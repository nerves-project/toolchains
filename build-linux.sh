#!/bin/sh

set -e

ERLANG_VERSION=18.1
CTNG_TAG=625f7e66b43c8629c7ca27b062ff7adad9c2b859
BASE_DIR=`pwd`
WORK_DIR=$BASE_DIR/work
DL_DIR=$BASE_DIR/dl

NERVES_TOOLCHAIN_TAG=`git describe --always --dirty`
HOST_ARCH=`uname -m`

# Programs used for building the toolchain, but not for distributing (e.g. ct-ng)
LOCAL_INSTALL_DIR=$WORK_DIR/usr

# Install directories for the tools we make
ERL_INSTALL_DIR=$WORK_DIR/erl
GCC_INSTALL_DIR=$WORK_DIR/x-tools  # make sure that this is the same as in the config file

init()
{
    # Clean up an old build
    chmod -R u+w $WORK_DIR
    rm -fr $WORK_DIR

    mkdir -p $WORK_DIR
    mkdir -p $INSTALL_DIR
    mkdir -p $DL_DIR
}

gcc_tuple()
{
    # Figure out the target's tuple. It's the name of the only directory.
    tuplepath=`ls $GCC_INSTALL_DIR`
    if [ -e $tuplepath ]; then
        echo "unknown"
    else
        echo `basename $tuplepath`
    fi
}

build_gcc()
{
    # Build and install ct-ng to the work directory
    cd $WORK_DIR
    git clone https://github.com/crosstool-ng/crosstool-ng.git
    cd crosstool-ng
    git checkout $CTNG_TAG

    ./bootstrap
    ./configure --prefix=$LOCAL_INSTALL_DIR
    make
    make install

    # Build the toolchain
    mkdir -p $WORK_DIR/build
    cd $WORK_DIR/build
    cp $BASE_DIR/configs/linux.config .config
    $LOCAL_INSTALL_DIR/bin/ct-ng build

    TARGET_TUPLE=`gcc_tuple`

    # ct-ng likes to mark everything read-only which
    # seems reasonable, but it can be really annoying.
    chmod -R u+w $GCC_INSTALL_DIR/$TARGET_TUPLE

    # Clean up the build product
    rm -f $GCC_INSTALL_DIR/$TARGET_TUPLE/build.log.bz2
}

build_erlang()
{
    # Build and install ct-ng to the work directory
    cd $WORK_DIR

    ERLANG_SRC=otp_src_$ERLANG_VERSION
    ERLANG_TAR_GZ=$ERLANG_SRC.tar.gz
    [ -e $DL_DIR/$ERLANG_TAR_GZ ] || wget -O $DL_DIR/$ERLANG_TAR_GZ http://www.erlang.org/download/$ERLANG_TAR_GZ

    rm -fr $ERLANG_SRC
    tar xf $DL_DIR/$ERLANG_TAR_GZ
    cd $ERLANG_SRC

    # Disabling HiPE is the most important part, since we don't support HiPE
    # in Nerves. It is crucial that erlc not precompile anything or else the
    # BEAM files won't run on the target.
    #
    # While we're at it, disable a few more things to make the install smaller and
    # to hopefully dissuade anyone from using this Erlang install for much more than
    # running erlc.
    #
    # NOTE: All OTP applications (possibly barring the GUI ones) are enabled
    #  on the embedded side. The ones here aren't used for the embedded side since
    #  they may contain x86 code or other desktop-specific settings. We still
    #  need a compatible erlc on the host, though, and that's what this is all about.
    ./configure --prefix=$ERL_INSTALL_DIR --disable-hipe --without-javac --disable-sctp \
        --without-termcap --without-odbc --without-wx --without-megaco --without-snmp \
        --without-gs --without-otp_mibs --without-jinterface --without-diameter \
        --without-orber --without-cosTransactions --without-cosEvent --without-cosTime \
        --without-cosNotification --without-cosProperty --without-cosFileTransfer \
        --without-cosEventDomain --without-ose
    make
    make install
}

assemble_tarball()
{
    echo Building archive...

    # Assemble the tarball for the toolchain
    TARGET_TUPLE=`gcc_tuple`
    TARBALL_PATH=$BASE_DIR/nerves-toolchain-$TARGET_TUPLE-linux-$HOST_ARCH-$NERVES_TOOLCHAIN_TAG.tar
    TARXZ_PATH=$TARBALL_PATH.xz

    echo "$NERVES_TOOLCHAIN_TAG" > $GCC_INSTALL_DIR/$TARGET_TUPLE/nerves-toolchain.tag
    rm -f $TARBALL_PATH $TARXZ_PATH
    tar c -C $GCC_INSTALL_DIR -f $TARBALL_PATH $TARGET_TUPLE
    tar r -C $WORK_DIR -f $TARBALL_PATH --transform "s,^erl,$TARGET_TUPLE," erl
    xz $TARBALL_PATH
}

init
build_gcc
build_erlang
assemble_tarball

