#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

# Example
#
# build.sh <config name> [work directory] [output directory]

set -eo pipefail

cleanup()
{
    local status=$?
    if ! cleanup_build_drive; then
        if [[ $status = 0 ]]; then status=1; fi
    fi
    exit "$status"
}

cleanup_build_drive()
{
    if [[ ${WORK_DMG_CREATED:-} != true || ${DEBUG+x} ]]; then
        return 0
    fi

    cd "$SCRIPT_DIR" || return 1
    if [[ -n ${WORK_DMG_DEVICE:-} || -d /Volumes/$WORK_DMG_VOLNAME ]]; then
        if ! diskutil eject "${WORK_DMG_DEVICE:-/Volumes/$WORK_DMG_VOLNAME}"; then
            echo "Could not unmount build drive; keeping $WORK_DMG" >&2
            return 1
        fi
    fi
    rm -f "$WORK_DIR" "$WORK_DMG"
}

trap cleanup EXIT

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TOOLCHAIN_NAME=${1:-}

if [[ ! -f "$SCRIPT_DIR/configs/$TOOLCHAIN_NAME.defconfig" ]]; then
    echo "Pass a config name (e.g., armv7-nerves-linux-gnueabihf--gcc15)" >&2
    exit 1
fi

BASE_CONFIG="$SCRIPT_DIR/configs/$TOOLCHAIN_NAME.defconfig"
WORK_DIR=${2:-"$SCRIPT_DIR/o/$TOOLCHAIN_NAME"}
OUTPUT_DIR=${3:-"$SCRIPT_DIR/o/artifacts"}

READLINK=readlink
BUILD_ARCH=$(uname -m)
BUILD_OS=$(uname -s | awk '{print tolower($0)}')
if [[ $BUILD_OS = "cygwin_nt-6.1" ]]; then
    # A simple cygwin looks better.
    BUILD_OS="cygwin"
elif [[ $BUILD_OS = "darwin" ]]; then
    # Make sure that we use GNU readlink on OSX
    READLINK=greadlink
fi

if [[ -z $HOST_ARCH ]]; then
    HOST_ARCH=$BUILD_ARCH
fi
if [[ -z $HOST_OS ]]; then
    HOST_OS=$BUILD_OS
fi

ARTIFACT_HOST_ARCH=$HOST_ARCH
if [[ $HOST_OS = "darwin" && ( $HOST_ARCH = "arm64" || $HOST_ARCH = "aarch64" ) ]]; then
    ARTIFACT_HOST_ARCH="arm"
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$($READLINK -f "$OUTPUT_DIR")

EXISTING_ARCHIVE=$(bash "$SCRIPT_DIR/scripts/archive.sh" --find "$OUTPUT_DIR" \
    "$TOOLCHAIN_NAME" "${HOST_OS}_${ARTIFACT_HOST_ARCH}" "$(cat "$SCRIPT_DIR/VERSION")")
if [[ -n $EXISTING_ARCHIVE ]]; then
    (cd "$OUTPUT_DIR" && sha256sum -- "$(basename "$EXISTING_ARCHIVE")" | \
        cmp - "$(basename "$EXISTING_ARCHIVE").sha256")
    echo "Skipping $TOOLCHAIN_NAME: already built at $EXISTING_ARCHIVE"
    exit 0
fi

# Ensure that the config and work paths are absolute
BASE_CONFIG=$($READLINK -f "$BASE_CONFIG")
if [[ -L $WORK_DIR ]]; then rm -f "$WORK_DIR"; fi
mkdir -p "$WORK_DIR"
WORK_DIR=$($READLINK -f "$WORK_DIR")

# Append host-specific modifications to the base defconfig
HOST_CONFIG=$SCRIPT_DIR/defaults/${HOST_OS}_${HOST_ARCH}_defconfig
if [[ ! -e $HOST_CONFIG ]]; then
    echo "Can't find a ${HOST_OS}_${HOST_ARCH}_defconfig fragment. Check that one exists."
    exit 1
fi

DL_DIR=$HOME/.nerves/dl
mkdir -p "$SCRIPT_DIR/o/tmp"
export TMPDIR="$SCRIPT_DIR/o/tmp"

echo "Using HOST_ARCH: $HOST_ARCH"
echo "Using HOST_OS: $HOST_OS"
echo "Using BUILD_OS: $BUILD_OS"
echo
echo "Output directory: $OUTPUT_DIR"
echo "Work directory: $WORK_DIR"
echo

# Install directories for the tools we make
GCC_INSTALL_DIR="$WORK_DIR/x-tools"  # make sure that this is the same as in the config file

if [[ "$CI" = "true" ]]; then
    # CircleCI runs out of memory if too many concurrent builds go at once
    CTNG_BUILD=build.4
else
    CTNG_BUILD=build
fi

if [[ $BUILD_OS = "darwin" ]]; then
    # Mac-specific updates

    export MACOSX_DEPLOYMENT_TARGET=15.0

    WORK_DMG="$WORK_DIR.dmg"
    WORK_DMG_VOLNAME=$TOOLCHAIN_NAME

    # Used by crosstool-ng's configure script
    export CURSES_LIBS="-L$(brew --prefix ncurses)/lib -lncursesw"

    # Apple provides an old version of Bison that will fail about 20 minutes into the build.
    export PATH="$(brew --prefix bison)/bin:$PATH"
    BISON="$(brew --prefix bison)/bin/bison"
    if [[ ! -e "$BISON" ]]; then
        echo "Building gcc requires a more recent version on bison than Apple provides. Install with 'brew install bison'"
        echo "Expecting to find bison at '$BISON'."
        exit 1
    fi

    export PATH="$(brew --prefix m4)/bin:$PATH"
    M4="$(brew --prefix m4)/bin/m4"
    if [[ ! -e "$M4" ]]; then
        echo "Building gcc requires a more recent version on m4 than Apple provides. Install with 'brew install m4'"
        echo "Expecting to find m4 at '$M4'."
        exit 1
    fi

    # Pull in GNU grep
    export PATH="$(brew --prefix grep)/libexec/gnubin:$PATH"
    GREP="$(brew --prefix grep)/libexec/gnubin/grep"
    if [[ ! -e "$GREP" ]]; then
        echo "Building gcc requires GNU grep. Install with 'brew install grep'"
        echo "Expecting to find grep at '$GREP'."
        exit 1
    fi

elif [[ $BUILD_OS = "linux" ]]; then
    # Linux-specific updates
    :
elif [[ $BUILD_OS = "freebsd" ]]; then
    # BSD-specific updates
    # For crosstool-ng
    export AWK=gawk
else
    echo "unknown host OS: $BUILD_OS"
    exit 1
fi

init()
{
    # Clean up an old build and create the work directory
    if [[ $BUILD_OS = "darwin" ]]; then
        diskutil eject "/Volumes/$WORK_DMG_VOLNAME" 2>/dev/null || true
        rm -fr "$WORK_DIR" "$WORK_DMG"
        WORK_DMG_CREATED=true
        # Sequoia has the image API but not its --fs option.
        if diskutil image create blank --help 2>/dev/null | grep -q -- '--fs'; then
            # The image API cannot create case-sensitive filesystems directly.
            local device
            diskutil image create blank --size 32g --fs None "$WORK_DMG"
            device=$(diskutil image attach --noMount "$WORK_DMG")
            WORK_DMG_DEVICE=$device
            diskutil eraseDisk HFSX "$WORK_DMG_VOLNAME" "$device"
        else
            hdiutil create -size 32g -fs "Case-sensitive HFS+" -volname "$WORK_DMG_VOLNAME" "$WORK_DMG"
            hdiutil attach "$WORK_DMG"
        fi
        ln -s "/Volumes/$WORK_DMG_VOLNAME" "$WORK_DIR"
    elif [[ $BUILD_OS = "linux" || $BUILD_OS = "cygwin" || $BUILD_OS = "freebsd" ]]; then
        if [[ -e "$WORK_DIR" ]]; then
            chmod -R u+w "$WORK_DIR"
            rm -fr "$WORK_DIR"
        fi
        mkdir -p "$WORK_DIR"
    fi

    mkdir -p "$GCC_INSTALL_DIR"
    mkdir -p "$DL_DIR"
}

build_gcc()
{
    if [[ $BUILD_OS = darwin || $BUILD_OS = freebsd ]]; then
        gmake -C "$SCRIPT_DIR" ctng
    else
        make -C "$SCRIPT_DIR" ctng
    fi
    CTNG="$SCRIPT_DIR/o/ct-ng/bin/ct-ng"

    # Setup the toolchain build directory
    mkdir -p "$WORK_DIR/build"
    cd "$WORK_DIR/build"
    CTNG_CONFIG=$PWD/defconfig
    {
        cat "$BASE_CONFIG"
        printf '\n'
        cat "$HOST_CONFIG"
        if [[ "$CI" = "true" ]]; then
            printf '\n'
            cat "$SCRIPT_DIR/defaults/ci_defconfig"
        fi
    } > "$CTNG_CONFIG"

    # Process the configuration
    $CTNG defconfig

    # Save the defconfig back for later review
    cp "$CTNG_CONFIG" "$CTNG_CONFIG.orig"
    $CTNG savedefconfig

    echo "Original defconfig"
    cat "$CTNG_CONFIG.orig"
    echo "Resaved defconfig"
    cat "$CTNG_CONFIG"

    # savedefconfig omits explicit defaults; validate against the full configuration.
    bash "$SCRIPT_DIR/scripts/archive.sh" --check-config "$BASE_CONFIG" "$WORK_DIR/build/.config"

    $CTNG $CTNG_BUILD

    local compilers=("$GCC_INSTALL_DIR"/*/bin/*-gcc)
    if [[ ${#compilers[@]} != 1 || ! -f ${compilers[0]} ]]; then
        echo "Expected exactly one installed *-gcc compiler under $GCC_INSTALL_DIR" >&2
        exit 1
    fi
    TARGET_TUPLE=${compilers[0]##*/}
    TARGET_TUPLE=${TARGET_TUPLE%-gcc}
    INSTALL_DIR=${compilers[0]%/bin/*}

    echo "Fixing permissions on release"
    # ct-ng likes to mark everything read-only which seems reasonable, but it
    # can be really annoying when trying to cleanup a toolchain.
    chmod -R u+w "$INSTALL_DIR"

    # Clean up the build product
    rm -f "$INSTALL_DIR/build.log.bz2"
}

save_build_info()
{
    # Save useful information if we ever need to reproduce the toolchain
    cp "$CTNG_CONFIG" "$INSTALL_DIR/ct-ng.defconfig"
    cp "$WORK_DIR/build/.config" "$INSTALL_DIR/ct-ng.config"
    local recipe="$INSTALL_DIR/share/toolchain-builder"
    mkdir -p "$recipe"
    cp "$SCRIPT_DIR"/{VERSION,Makefile,LICENSE,README.md} "$recipe/"
    cp -R "$SCRIPT_DIR"/{scripts,configs,defaults,patches} "$recipe/"
}

fix_kernel_case_conflicts()
{
    # On Macs, the file system is case-preserving, but case-insensitive. The netfilter
    # module in the Linux kernel provides header files that differ only in case, so this
    # won't work if you need to use both the capitalized and lowercase versions of the
    # header files.
    #
    # The workaround is to remove case conflicts in the kernel include
    # directory so that users don't need to use case sensitive filesystems on
    # OSX.
    LINUX_INCLUDE_DIR=$INSTALL_DIR/$TARGET_TUPLE/sysroot/usr/include/linux
    rm -f "$LINUX_INCLUDE_DIR/netfilter/xt_CONNMARK.h" \
          "$LINUX_INCLUDE_DIR/netfilter/xt_DSCP.h" \
          "$LINUX_INCLUDE_DIR/netfilter/xt_MARK.h" \
          "$LINUX_INCLUDE_DIR/netfilter/xt_RATEEST.h" \
          "$LINUX_INCLUDE_DIR/netfilter/xt_TCPMSS.h" \
          "$LINUX_INCLUDE_DIR/netfilter_ipv4/ipt_ECN.h" \
          "$LINUX_INCLUDE_DIR/netfilter_ipv4/ipt_TTL.h" \
          "$LINUX_INCLUDE_DIR/netfilter_ipv6/ip6t_HL.h"
}

finalize_products()
{
    echo "Beginning of finalize_products"
    save_build_info

    if [[ $BUILD_OS = "darwin" ]]; then
        # Prune out filenames with case conflicts and before make a tarball
        fix_kernel_case_conflicts
    elif [[ $HOST_OS = "linux" || $HOST_OS = "freebsd" ]]; then
        # Linux and FreeBSD don't have the case issues
        echo ""
    else
        # macOS and Windows are case insensitive by default, so fix the conflicts
        fix_kernel_case_conflicts
    fi
}

build_artifact()
{
    bash "$SCRIPT_DIR/scripts/package.sh" "$INSTALL_DIR" "$OUTPUT_DIR" "${HOST_OS}_${ARTIFACT_HOST_ARCH}"
}

init
build_gcc
finalize_products
build_artifact

echo "Success!"
echo
echo "Generated archives in: $OUTPUT_DIR."
