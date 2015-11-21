#!/bin/sh

set -e

ERLANG_VERSION=18.1
ELIXIR_VERSION=1.1.1
CTNG_TAG=625f7e66b43c8629c7ca27b062ff7adad9c2b859

BASE_DIR=$(pwd)

if [ $# -lt 1 ]; then
    echo "Usage: $0 <config name>"
    echo
    echo "By convention, configurations are identified by <host>-<libc>-<abi>. The following"
    echo "are some examples (look in the configs directory for more):"
    echo
    echo "linux-glibc-eabihf   -> Linux host, glibc on the target, hardware float"
    echo "osx-glibc-eabihf     -> Mac host, glibc on the target, hardware float"
    exit 1
fi

CONFIG=$1
CTNG_CONFIG=$BASE_DIR/configs/$CONFIG.config

if [ ! -e $CTNG_CONFIG ]; then
    echo "Can't find $CTNG_CONFIG. Check that it exists."
    exit 1
fi

WORK_DIR=$BASE_DIR/work-$CONFIG
DL_DIR=$BASE_DIR/dl

NERVES_TOOLCHAIN_TAG=$(git describe --always --dirty)
HOST_ARCH=$(uname -m)
HOST_OS=$(uname -s)

# Programs used for building the toolchain, but not for distributing (e.g. ct-ng)
LOCAL_INSTALL_DIR=$WORK_DIR/usr

# Install directories for the tools we make
GCC_INSTALL_DIR=$WORK_DIR/x-tools  # make sure that this is the same as in the config file
ERL_INSTALL_DIR=$WORK_DIR/erlang-install
ELIXIR_INSTALL_DIR=$WORK_DIR/elixir-install

if [ $HOST_OS = "Darwin" ]; then
    # Mac-specific updates

    # We run out of file handles when building for Mac
    ulimit -n 512

    # Need to specify the OpenSSL location
    ERLANG_CONFIGURE_ARGS=--with-ssl=/usr/local/bin

    CTNG_CC=/usr/local/bin/gcc-5
    CTNG_CXX=/usr/local/bin/c++-5

    WORK_DMG=$WORK_DIR.dmg
    WORK_DMG_VOLNAME=nerves-toolchain-work
elif [ $HOST_OS = "Linux" ]; then
    # Linux-specific updates

    CTNG_CC=/usr/bin/gcc
    CTNG_CXX=/usr/bin/c++
else
    echo "Unknown host OS: $HOST_OS"
    exit 1
fi

init()
{
    # Clean up an old build and create the work directory
    if [ $HOST_OS = "Darwin" ]; then
        hdiutil detach /Volumes/$WORK_DMG_VOLNAME || true
        rm -fr $WORK_DIR $WORK_DMG
        hdiutil create -size 10g -fs "Case-sensitive HFS+" -volname $WORK_DMG_VOLNAME $WORK_DMG
        hdiutil attach $WORK_DMG
        ln -s /Volumes/$WORK_DMG_VOLNAME $WORK_DIR
    elif [ $HOST_OS = "Linux" ]; then
        if [ -e $WORK_DIR ]; then
            chmod -R u+w $WORK_DIR
            rm -fr $WORK_DIR
        fi
        mkdir -p $WORK_DIR
    fi

    mkdir -p $ERL_INSTALL_DIR
    mkdir -p $GCC_INSTALL_DIR
    mkdir -p $DL_DIR
}

gcc_tuple()
{
    # Figure out the target's tuple. It's the name of the only directory.
    tuplepath=$(ls $GCC_INSTALL_DIR)
    if [ -e $tuplepath ]; then
        echo "unknown"
    else
        echo $(basename $tuplepath)
    fi
}

build_gcc()
{
    # Build and install ct-ng to the work directory
    cd $WORK_DIR
    ln -sf $DL_DIR dl
    rm -fr crosstool-ng
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
    DEFCONFIG=$CTNG_CONFIG $LOCAL_INSTALL_DIR/bin/ct-ng defconfig
    CC=$CTNG_CC CXX=$CTNG_CXX $LOCAL_INSTALL_DIR/bin/ct-ng build

    TARGET_TUPLE=$(gcc_tuple)

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
    [ -e $DL_DIR/$ERLANG_TAR_GZ ] || curl -L -o $DL_DIR/$ERLANG_TAR_GZ http://www.erlang.org/download/$ERLANG_TAR_GZ

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
        --without-cosEventDomain --without-ose $ERLANG_CONFIGURE_ARGS
    make -j6
    make install

    # Fix up the absolute paths in the scripts
    find $ERL_INSTALL_DIR -type f \( -name "start" -o -name "erl" \) | \
        xargs -n 1 $BASE_DIR/scripts/fix-erlang-abspaths.py $ERL_INSTALL_DIR
}

build_elixir()
{
    # Build and install ct-ng to the work directory
    cd $WORK_DIR

    ELIXIR_ZIP=elixir-$ELIXIR_VERSION-precompiled.zip
    [ -e $DL_DIR/$ELIXIR_ZIP ] || curl -L -o $DL_DIR/$ELIXIR_ZIP https://github.com/elixir-lang/elixir/releases/download/v$ELIXIR_VERSION/Precompiled.zip

    # Elixir is so easy to "install"
    rm -fr $ELIXIR_INSTALL_DIR
    unzip -d $ELIXIR_INSTALL_DIR $DL_DIR/$ELIXIR_ZIP
}

assemble_tarball()
{
    echo Building archive...

    # Assemble the tarball for the toolchain
    TARGET_TUPLE=$(gcc_tuple)
    TARBALL_PATH=$BASE_DIR/nerves-toolchain-$TARGET_TUPLE-linux-$HOST_ARCH-$NERVES_TOOLCHAIN_TAG.tar
    TARXZ_PATH=$TARBALL_PATH.xz

    echo "$NERVES_TOOLCHAIN_TAG" > $GCC_INSTALL_DIR/$TARGET_TUPLE/nerves-toolchain.tag
    rm -f $TARBALL_PATH $TARXZ_PATH
    tar c -C $GCC_INSTALL_DIR -f $TARBALL_PATH --transform "s,^$TARGET_TUPLE,nerves-toolchain," $TARGET_TUPLE
    tar r -C $WORK_DIR -f $TARBALL_PATH --transform "s,^erlang-install,nerves-toolchain," erlang-install
    tar r -C $WORK_DIR -f $TARBALL_PATH --transform "s,^elixir-install,nerves-toolchain," elixir-install
    xz $TARBALL_PATH
}

assemble_dmg()
{
    echo Building DMG...

    # Assemble the tarball for the toolchain
    TARGET_TUPLE=`gcc_tuple`
    DMG_PATH=$BASE_DIR/nerves-toolchain-$TARGET_TUPLE-linux-$HOST_ARCH-$NERVES_TOOLCHAIN_TAG.dmg

    echo "$NERVES_TOOLCHAIN_TAG" > $GCC_INSTALL_DIR/$TARGET_TUPLE/nerves-toolchain.tag
    rm -f $DMG_PATH
    hdiutil create -fs "Case-sensitive HFS+" -volname nerves-toolchain \
                    -srcfolder $WORK_DIR/x-tools/$TARGET_TUPLE/. \
                    -srcfolder $WORK_DIR/erlang-install/. \
                    -srcfolder $WORK_DIR/elixir-install/. \
                    $DMG_PATH
}

assemble_products()
{
    if [ $HOST_OS = "Darwin" ]; then
        assemble_dmg
    elif [ $HOST_OS = "Linux" ]; then
        assemble_tarball
    fi
}

fini()
{
    if [ $HOST_OS = "Darwin" ]; then
        hdiutil detach /Volumes/$WORK_DMG_VOLNAME || true
    fi
}

init
build_gcc
build_erlang
build_elixir
assemble_products
fini

echo "All done!"
