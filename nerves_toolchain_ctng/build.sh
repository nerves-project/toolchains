#!/usr/bin/env bash

set -e

# Set CTNG_USE_GIT=true to use git to download the release (only needed for non-released ct-ng builds)
CTNG_USE_GIT=true
CTNG_TAG=7300eb17b43a38320d25dff47230f483a82b4154

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR=$SCRIPT_DIR/..

BUILD_ARCH=$(uname -m)
BUILD_OS=$(uname -s)
if [[ $BUILD_OS = "CYGWIN_NT-6.1" ]]; then
    # A simple Cygwin looks better.
    BUILD_OS="cygwin"
fi
BUILD_OS=$(echo "$BUILD_OS" | awk '{print tolower($0)}')

if [[ -z $HOST_ARCH ]]; then
    HOST_ARCH=$BUILD_ARCH
fi
if [[ -z $HOST_OS ]]; then
    HOST_OS=$BUILD_OS
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <toolchain name>"
    echo
    echo "This is the Nerves toolchain builder. It produces cross-compilers that"
    echo "work across the operating systems supported by Nerves."
    echo
    echo "By convention, toolchains are identified by gcc tuples but using underscores"
    echo "instead of hyphens to make the names Elixir/Erlang friendly."
    echo
    echo "To do Canadian-cross builds (cross-compile the cross-compiler), set the"
    echo "HOST_ARCH and HOST_OS environment variables to what you want."
    echo
    echo "Valid options:"
    for dir in $(ls $BASE_DIR); do
        if [[ -f $dir/defconfig ]]; then
            echo $dir
        fi
    done
    exit 1
fi

CONFIG=$HOST_OS-$HOST_ARCH-$1
CTNG_CONFIG_DIR=$BASE_DIR/$1

BASE_CONFIG=$CTNG_CONFIG_DIR/defconfig
if [[ ! -e $BASE_CONFIG ]]; then
    echo "Can't find $BASE_CONFIG. Check that it exists."
    exit 1
fi

# Append host-specific modifications to the base defconfig
HOST_CONFIG=$CTNG_CONFIG_DIR/${HOST_OS}_${HOST_ARCH}_defconfig
if [[ ! -e $HOST_CONFIG ]]; then
    HOST_CONFIG=$SCRIPT_DIR/defaults/${HOST_OS}_${HOST_ARCH}_defconfig
    if [[ ! -e $HOST_CONFIG ]]; then
        echo "Can't find a ${HOST_OS}_${HOST_ARCH}_defconfig fragment. Check that one exists."
        exit 1
    fi
fi

WORK_DIR=$BASE_DIR/work-$CONFIG
DL_DIR=$BASE_DIR/dl

if [[ ! -e $CTNG_CONFIG_DIR/VERSION ]]; then
    echo "Can't find $CTNG_CONFIG_DIR/VERSION. Check that it exists."
    exit 1
fi

NERVES_TOOLCHAIN_VERSION=$(cat $CTNG_CONFIG_DIR/VERSION | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# Programs used for building the toolchain, but not for distributing (e.g. ct-ng)
LOCAL_INSTALL_DIR=$WORK_DIR/usr

# Install directories for the tools we make
GCC_INSTALL_DIR=$WORK_DIR/x-tools  # make sure that this is the same as in the config file

if [[ $BUILD_OS = "darwin" ]]; then
    # Mac-specific updates

    # We run out of file handles when building for Mac
    ulimit -n 512

    # Use GNU tar from Homebrew (brew install gnu-tar)
    TAR=gtar

    WORK_DMG=$WORK_DIR.dmg
    WORK_DMG_VOLNAME=nerves-toolchain-work

elif [[ $BUILD_OS = "linux" ]]; then
    # Linux-specific updates
    TAR=tar
elif [[ $BUILD_OS = "cygwin" || $BUILD_OS = "freebsd" ]]; then
    # Windows-specific updates
    TAR=tar

    # For crosstool-ng
    export AWK=gawk
else
    echo "Unknown host OS: $BUILD_OS"
    exit 1
fi

init()
{
    # Clean up an old build and create the work directory
    if [[ $BUILD_OS = "darwin" ]]; then
        hdiutil detach /Volumes/$WORK_DMG_VOLNAME 2>/dev/null || true
        rm -fr $WORK_DIR $WORK_DMG
        hdiutil create -size 10g -fs "Case-sensitive HFS+" -volname $WORK_DMG_VOLNAME $WORK_DMG
        hdiutil attach $WORK_DMG
        ln -s /Volumes/$WORK_DMG_VOLNAME $WORK_DIR
    elif [[ $BUILD_OS = "linux" || $BUILD_OS = "cygwin" || $BUILD_OS = "freebsd" ]]; then
        if [[ -e $WORK_DIR ]]; then
            chmod -R u+w $WORK_DIR
            rm -fr $WORK_DIR
        fi
        mkdir -p $WORK_DIR
    fi

    mkdir -p $GCC_INSTALL_DIR
    mkdir -p $DL_DIR
}

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

gcc_tuple_underscores()
{
    echo $(gcc_tuple) | tr - _
}

build_gcc()
{
    # Build and install ct-ng to the work directory
    cd $WORK_DIR
    ln -sf $DL_DIR dl
    rm -fr crosstool-ng

    CTNG_TAR_XZ=crosstool-ng-$CTNG_TAG.tar.xz
    if [[ ! -e $DL_DIR/$CTNG_TAR_XZ ]]; then
        if [[ $CTNG_USE_GIT = "true" ]]; then
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

    # Apply patches
    $SCRIPT_DIR/scripts/apply-patches.sh crosstool-ng $SCRIPT_DIR/patches/crosstool-ng

    cd crosstool-ng
    if [[ $CTNG_USE_GIT = "true" ]]; then
        ./bootstrap
    fi
    if [[  $BUILD_OS = "freebsd" ]]; then
	./configure --prefix=$LOCAL_INSTALL_DIR --with-sed=/usr/local/bin/gsed --with-make=/usr/local/bin/gmake --with-patch=/usr/local/bin/gpatch
	gmake
	gmake install
    else
	./configure --prefix=$LOCAL_INSTALL_DIR
	make
	make install
    fi

    # Setup the toolchain build directory
    mkdir -p $WORK_DIR/build
    cd $WORK_DIR/build
    CTNG_CONFIG=$WORK_DIR/build/defconfig
    cat $BASE_CONFIG $HOST_CONFIG >> $CTNG_CONFIG

    # Process the configuration
    DEFCONFIG=$CTNG_CONFIG $LOCAL_INSTALL_DIR/bin/ct-ng defconfig

    # Save the defconfig back for later review
    $LOCAL_INSTALL_DIR/bin/ct-ng savedefconfig

    # Build the toolchain
    if [[ -z $CTNG_CC ]]; then
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

toolchain_base_name()
{
    # Compute the base filename part of the build product
    echo "nerves_toolchain_$(gcc_tuple_underscores)-$NERVES_TOOLCHAIN_VERSION.$HOST_OS-$HOST_ARCH"
}

assemble_tarball()
{
    echo Building archive...

    # Assemble the tarball for the toolchain
    TARGET_TUPLE=$(gcc_tuple)
    TARBALL_PATH=$BASE_DIR/$(toolchain_base_name).tar
    TARXZ_PATH=$TARBALL_PATH.xz
    TOOLCHAIN_BASE_NAME=$(toolchain_base_name)

    # Save useful information if we ever need to reproduce the toolchain
    echo "$NERVES_TOOLCHAIN_VERSION" > $GCC_INSTALL_DIR/$TARGET_TUPLE/nerves-toolchain.tag
    cp $CTNG_CONFIG $GCC_INSTALL_DIR/$TARGET_TUPLE/ct-ng.defconfig
    cp $WORK_DIR/build/.config $GCC_INSTALL_DIR/$TARGET_TUPLE/ct-ng.config

    rm -f $TARBALL_PATH $TARXZ_PATH
    $TAR c -C $GCC_INSTALL_DIR -f $TARBALL_PATH --transform "s,^$TARGET_TUPLE,$TOOLCHAIN_BASE_NAME," $TARGET_TUPLE
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

    echo "$NERVES_TOOLCHAIN_VERSION" > $GCC_INSTALL_DIR/$TARGET_TUPLE/nerves-toolchain.tag
    rm -f $DMG_PATH
    hdiutil create -fs "Case-sensitive HFS+" -volname nerves-toolchain \
                    -srcfolder $WORK_DIR/x-tools/$TARGET_TUPLE/. \
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
    if [[ $BUILD_OS = "darwin" ]]; then
        # On OSX, always create .dmg files for debugging builds and
        # fix the case issues.

        # Assemble .dmg file first
        assemble_dmg

        # Prune out filenames with case conflicts and make a tarball
        fix_kernel_case_conflicts
        assemble_tarball
    elif [[ $HOST_OS = "linux" || $HOST_OS = "freebsd" ]]; then
        # Linux and FreeBSD don't have the case issues
        assemble_tarball
    else
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
    if [[ $BUILD_OS = "darwin" ]]; then
        # Try to unmount. It never works immediately, so wait before trying.
        sleep 5
        hdiutil detach /Volumes/$WORK_DMG_VOLNAME -force || true
        rm -f $WORK_DMG
    fi
    rm -fr $WORK_DIR
}

init
build_gcc
assemble_products
fini

echo "All done!"
