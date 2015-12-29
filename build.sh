#!/bin/bash

set -e

ERLANG_VERSION=18.1
ELIXIR_VERSION=1.1.1

# Set CTNG_USE_GIT=true to use git to download the release (only needed for non-released ct-ng builds)
CTNG_USE_GIT=false
CTNG_TAG=1.22.0

BASE_DIR=$(pwd)

HOST_ARCH=$(uname -m)
HOST_OS=$(uname -s)
if [ $HOST_OS = "CYGWIN_NT-6.1" ]; then
    # A simple Cygwin looks better.
    HOST_OS="Cygwin"
fi

if [ $# -lt 1 ]; then
    echo "Usage: $0 <config fragment>"
    echo
    echo "This is the Nerves toolchain builder. Toolchains include a cross-compiler,"
    echo "an Erlang compiler matched to the one used in the Nerves system images,"
    echo "and a matched Elixir compiler."
    echo
    echo "By convention, configurations are identified by <host>-<libc>-<arch/abi>."
    echo "The following are some examples (look in the configs directory for details):"
    echo
    echo "Linux-glibc-eabihf.config  -> Linux host, ARM target with glibc, hardware float"
    echo "Darwin-glibc-eabihf.config -> Mac host, ARM target with glibc, hardware float"
    echo
    echo "Pass the <libc>-<arch/abi> part for the first parameter."
    echo
    echo "Valid options for this platform:"
    for config in $(ls configs); do
        case $config in
            $HOST_OS-*)
                CONFIG_FRAGMENT=$(basename $config .config | sed -e "s/$HOST_OS-//")
                echo "  $0 $CONFIG_FRAGMENT"
                ;;
            *)
        esac
    done
    exit 1
fi

CONFIG=$HOST_OS-$1
CTNG_CONFIG=$BASE_DIR/configs/$CONFIG.config

if [ ! -e $CTNG_CONFIG ]; then
    echo "Can't find $CTNG_CONFIG. Check that it exists."
    exit 1
fi

WORK_DIR=$BASE_DIR/work-$CONFIG
DL_DIR=$BASE_DIR/dl

NERVES_TOOLCHAIN_TAG=$(git describe --always --dirty)

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
    ERLANG_CONFIGURE_ARGS=--with-ssl=/usr/local/opt/openssl

    CTNG_CC=/usr/local/bin/gcc-5
    CTNG_CXX=/usr/local/bin/c++-5

    # Use GNU tar from Homebrew (brew install gnu-tar)
    TAR=gtar

    WORK_DMG=$WORK_DIR.dmg
    WORK_DMG_VOLNAME=nerves-toolchain-work

elif [ $HOST_OS = "Linux" ]; then
    # Linux-specific updates
    TAR=tar
elif [ $HOST_OS = "Cygwin" ]; then
    # Windows-specific updates
    TAR=tar

    # For crosstool-ng
    export AWK=gawk
else
    echo "Unknown host OS: $HOST_OS"
    exit 1
fi

init()
{
    # Clean up an old build and create the work directory
    if [ $HOST_OS = "Darwin" ]; then
        hdiutil detach /Volumes/$WORK_DMG_VOLNAME 2>/dev/null || true
        rm -fr $WORK_DIR $WORK_DMG
        hdiutil create -size 10g -fs "Case-sensitive HFS+" -volname $WORK_DMG_VOLNAME $WORK_DMG
        hdiutil attach $WORK_DMG
        ln -s /Volumes/$WORK_DMG_VOLNAME $WORK_DIR
    elif [ $HOST_OS = "Linux" ] || [ $HOST_OS = "Cygwin" ]; then
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
    # Don't call this until after build_gcc()
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

    CTNG_TAR_XZ=crosstool-ng-$CTNG_TAG.tar.xz
    if [ ! -e $DL_DIR/$CTNG_TAR_XZ ]; then
        if [ $CTNG_USE_GIT = "true" ]; then
            git clone https://github.com/crosstool-ng/crosstool-ng.git
            cd crosstool-ng
            git checkout $CTNG_TAG
            cd ..
            $TAR -c -J --exclude=.git -f $DL_DIR/$CTNG_TAR_XZ crosstool-ng
        else
            curl -L -o $DL_DIR/$CTNG_TAR_XZ http://crosstool-ng.org/download/crosstool-ng/$CTNG_TAR_XZ
            $TAR xf $DL_DIR/$CTNG_TAR_XZ
        fi
    else
        $TAR xf $DL_DIR/$CTNG_TAR_XZ
    fi

    cd crosstool-ng
    if [ $CTNG_USE_GIT = "true" ]; then
        ./bootstrap
    fi
    ./configure --prefix=$LOCAL_INSTALL_DIR
    make
    make install

    # Build the toolchain
    mkdir -p $WORK_DIR/build
    cd $WORK_DIR/build
    DEFCONFIG=$CTNG_CONFIG $LOCAL_INSTALL_DIR/bin/ct-ng defconfig
    if [ -z $CTNG_CC ]; then
        $LOCAL_INSTALL_DIR/bin/ct-ng build
    else
        CC=$CTNG_CC CXX=$CTNG_CXX $LOCAL_INSTALL_DIR/bin/ct-ng build
    fi

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
    $TAR xf $DL_DIR/$ERLANG_TAR_GZ
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

toolchain_base_name()
{
    # Compute the base filename part of the build product
    echo "nerves-toolchain-$TARGET_TUPLE-$HOST_OS-$HOST_ARCH-$NERVES_TOOLCHAIN_TAG"
}

assemble_tarball()
{
    echo Building archive...

    # Assemble the tarball for the toolchain
    TARGET_TUPLE=$(gcc_tuple)
    TARBALL_PATH=$BASE_DIR/$(toolchain_base_name).tar
    TARXZ_PATH=$TARBALL_PATH.xz

    echo "$NERVES_TOOLCHAIN_TAG" > $GCC_INSTALL_DIR/$TARGET_TUPLE/nerves-toolchain.tag
    rm -f $TARBALL_PATH $TARXZ_PATH
    $TAR c -C $GCC_INSTALL_DIR -f $TARBALL_PATH --transform "s,^$TARGET_TUPLE,nerves-toolchain," $TARGET_TUPLE
    $TAR r -C $WORK_DIR -f $TARBALL_PATH --transform "s,^erlang-install,nerves-toolchain," erlang-install
    $TAR r -C $WORK_DIR -f $TARBALL_PATH --transform "s,^elixir-install,nerves-toolchain," elixir-install
    xz $TARBALL_PATH
}

assemble_dmg()
{
    # On Macs, the file system is case-preserving, but case-insensitive. The netfilter
    # module in the Linux kernel provides header files that differ only in case, so this
    # won't work if you need to use both the capitalized and lowercase versions of the
    # header files. Therefore, the workaround is to create a case-sensitive .dmg file.
    #
    # This can be annoying since you need to use hdiutil to mount it, etc., so we also
    # create a tarball for OSX users that don't use netfilter with Nerves. Since the
    # Linux kernels shipped with Nerves don't even enable netfilter, it's likely that most
    # users will never notice.
    echo Building DMG...

    # Assemble the tarball for the toolchain
    TARGET_TUPLE=`gcc_tuple`
    DMG_PATH=$BASE_DIR/$(toolchain_base_name).dmg

    echo "$NERVES_TOOLCHAIN_TAG" > $GCC_INSTALL_DIR/$TARGET_TUPLE/nerves-toolchain.tag
    rm -f $DMG_PATH
    hdiutil create -fs "Case-sensitive HFS+" -volname nerves-toolchain \
                    -srcfolder $WORK_DIR/x-tools/$TARGET_TUPLE/. \
                    -srcfolder $WORK_DIR/erlang-install/. \
                    -srcfolder $WORK_DIR/elixir-install/. \
                    $DMG_PATH
}

fix_kernel_case_conflicts()
{
    # Remove case conflicts in the kernel include directory so that users don't need to
    # use case sensitive filesystems on OSX. See comment in assemble_dmg().
    TARGET_TUPLE=`gcc_tuple`
    LINUX_INCLUDE_DIR=$GCC_INSTALL_DIR/$TARGET_TUPLE/$TARGET_TUPLE/sysroot/usr/include/linux
    rm -f $LINUX_INCLUDE_DIR/netfilter/xt_CONNMARK.h \
          $LINUX_INCLUDE_DIR/netfilter/xt_DSCP.h \
          $LINUX_INCLUDE_DIR/netfilter/xt_MARK.h \
          $LINUX_INCLUDE_DIR/netfilter/xt_RATEEST.h \
          $LINUX_INCLUDE_DIR/netfilter/xt_TCPMSS.h \
          $LINUX_INCLUDE_DIR/netfilter_ipv4/ipt_ECN.h \
          $LINUX_INCLUDE_DIR/netfilter_ipv4/ipt_TTL.h \
          $LINUX_INCLUDE_DIR/netfilter_ipv6/ip6t_HL.h
}

assemble_products()
{
    if [ $HOST_OS = "Darwin" ]; then
        # Assemble .dmg file first
        assemble_dmg

        # Prune out filenames with case conflicts and make a tarball
        fix_kernel_case_conflicts
        assemble_tarball
    elif [ $HOST_OS = "Linux" ]; then
        assemble_tarball
    elif [ $HOST_OS = "Cygwin" ]; then
        # Windows is case insensitive by default, so fix the conflicts
        fix_kernel_case_conflicts
        assemble_tarball
    fi
}

fini()
{
    # Clean up our work since the disk space that it uses is quite significant
    # NOTE: If you're debugging ct-ng configs, you'll want to comment out the
    #       call to fini at the end.
    if [ $HOST_OS = "Darwin" ]; then
        # Try to unmount. It never works immediately, so wait before trying.
        sleep 5
        hdiutil detach /Volumes/$WORK_DMG_VOLNAME -force || true
        rm -f $WORK_DMG
    fi
    rm -fr $WORK_DIR
}

init
build_gcc
build_erlang
build_elixir
assemble_products
fini

echo "All done!"
