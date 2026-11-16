#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

# Example
#
# build.sh <config name> [work directory] [output directory]

set -e

terminate_descendants()
{
    local parent=$1 index

    for ((index = 0; index < ${#process_ids[@]}; index++)); do
        if [[ ${parent_ids[index]} = "$parent" ]]; then
            terminate_descendants "${process_ids[index]}"
            kill -TERM "${process_ids[index]}" 2>/dev/null || true
            stopped_ids+=("${process_ids[index]}")
        fi
    done
}

cleanup()
{
    local status=$? pid ppid
    local -a process_ids=() parent_ids=() stopped_ids=()
    trap '' INT TERM
    trap - EXIT

    # Snapshot before signaling so exiting parents cannot hide their children.
    while read -r pid ppid; do
        process_ids+=("$pid")
        parent_ids+=("$ppid")
    done < <(ps -axo pid=,ppid=)

    terminate_descendants "$$"

    if [[ ${#stopped_ids[@]} -gt 0 ]]; then
        sleep 1
        for pid in "${stopped_ids[@]}"; do
            kill -KILL "$pid" 2>/dev/null || true
        done
    fi

    wait 2>/dev/null || true
    exit "$status"
}

if [[ ${1:-} != --build-worker ]]; then
    # Background jobs ignore terminal SIGINT. Keep a supervising shell in wait
    # so Ctrl+C can terminate nested make and compiler jobs as well.
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    bash "$0" --build-worker "$@" &
    wait "$!"
    exit "$?"
fi

shift
trap cleanup EXIT

# Use hash or version tag (should be crosstool-ng-x.y.z)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ARTIFACT_NAME=${1:-}
TOOLCHAIN_NAME=$ARTIFACT_NAME

if [[ ! -f "$SCRIPT_DIR/configs/$TOOLCHAIN_NAME.defconfig" ]]; then
    echo "Pass a config name (e.g., armv7-nerves-linux-gnueabihf--gcc15)" >&2
    exit 1
fi

CTNG_TAG=$(elixir -e '{config, _} = Code.eval_file(hd(System.argv())); IO.puts(config.ctng_tag)' "$SCRIPT_DIR/config.exs")

BASE_CONFIG="$SCRIPT_DIR/configs/$TOOLCHAIN_NAME.defconfig"
WORK_DIR=${2:-"$SCRIPT_DIR/o/$TOOLCHAIN_NAME"}
OUTPUT_DIR=${3:-"$SCRIPT_DIR/o/artifacts"}

if [[ -z $WORK_DIR ]]; then
    echo "build.sh <work directory>"
    exit 1
fi

if [[ -z $OUTPUT_DIR ]]; then
    OUTPUT_DIR="$SCRIPT_DIR"
fi

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

# Ensure that the config and work paths are absolute
BASE_CONFIG=$($READLINK -f "$BASE_CONFIG")
rm -f "$WORK_DIR"
mkdir -p "$WORK_DIR"
WORK_DIR=$($READLINK -f "$WORK_DIR")

# Append host-specific modifications to the base defconfig
HOST_CONFIG=$SCRIPT_DIR/defaults/${HOST_OS}_${HOST_ARCH}_defconfig
if [[ ! -e $HOST_CONFIG ]]; then
    echo "Can't find a ${HOST_OS}_${HOST_ARCH}_defconfig fragment. Check that one exists."
    exit 1
fi

DL_DIR=$HOME/.nerves/dl

echo "Using HOST_ARCH: $HOST_ARCH"
echo "Using HOST_OS: $HOST_OS"
echo "Using BUILD_OS: $BUILD_OS"
echo
echo "Output directory: $OUTPUT_DIR"
echo "Work directory: $WORK_DIR"
echo

# Install directories for the tools we make
GCC_INSTALL_DIR="$WORK_DIR/x-tools"  # make sure that this is the same as in the config file

# Bump the number of open files. ct-ng does this now so this can be deleted when we're
# happy with it. (Probably the next time someone looks at these lines of code.)
n_open_files=$(ulimit -n)
if [ "${n_open_files}" -lt 2048 ]; then
     echo "Number of open files ${n_open_files} may not be sufficient to build the toolchain; increasing to 2048"
     ulimit -n 2048
fi

if [[ "$CI" = "true" ]]; then
    # CircleCI runs out of memory if too many concurrent builds go at once
    CTNG_BUILD=build.4
else
    CTNG_BUILD=build
fi

if [[ $BUILD_OS = "darwin" ]]; then
    # Mac-specific updates

    WORK_DMG="$WORK_DIR.dmg"
    WORK_DMG_VOLNAME=$ARTIFACT_NAME

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
        if diskutil image create blank --help >/dev/null 2>&1; then
            # The image API cannot create case-sensitive filesystems directly.
            local device
            diskutil image create blank --size 32g --fs None "$WORK_DMG"
            device=$(diskutil image attach --noMount "$WORK_DMG")
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
        if [[ -e "$CT_WORK_DIR" ]]; then
            chmod -R u+w "$CT_WORK_DIR"
            rm -fr "$CT_WORK_DIR"
        fi
        mkdir -p "$WORK_DIR"
    fi

    mkdir -p "$GCC_INSTALL_DIR"
    mkdir -p "$DL_DIR"
}

gcc_tuple()
{
    # Figure out the target's tuple. It's the name of the only directory.
    # Don't call this until after build_gcc()
    tuplepath=$(ls "$GCC_INSTALL_DIR")
    if [[ -e $tuplepath ]]; then
        echo "unknown"
    else
        basename "$tuplepath"
    fi
}

gcc_tuple_underscores()
{
    gcc_tuple | tr - _
}

build_gcc()
{
    CTNG=$(elixir "$SCRIPT_DIR/scripts/ctng.exs")
    if [[ $BUILD_OS = darwin ]]; then
        SED=gsed
    elif [[ $BUILD_OS = freebsd ]]; then
        SED=/usr/local/bin/gsed
    else
        SED="sed"
    fi

    # Setup the toolchain build directory
    mkdir -p "$WORK_DIR/build"
    cd "$WORK_DIR/build"
    CTNG_CONFIG=$PWD/defconfig
    { cat "$BASE_CONFIG"; printf '\n'; cat "$HOST_CONFIG"; } > "$CTNG_CONFIG"

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
    elixir "$SCRIPT_DIR/scripts/check_config.exs" "$BASE_CONFIG" "$WORK_DIR/build/.config"

    # Configure logging when on CI (see crosstool-ng's build script)
    if [[ "$CI" = "true" ]]; then
      echo "Modifying logging for CI"
      $SED -i -e 's/^.*\(CT_LOG_ERROR\).*$/# \1 is not set/' \
        -e 's/^.*\(CT_LOG_WARN\).*$/# \1 is not set/' \
        -e 's/^.*\(CT_LOG_INFO\).*$/# \1 is not set/' \
        -e 's/^.*\(CT_LOG_EXTRA\).*$/\1=y/' \
        -e 's/^.*\(CT_LOG_ALL\).*$/# \1 is not set/' \
        -e 's/^.*\(CT_LOG_DEBUG\).*$/# \1 is not set/' \
        -e 's/^.*\(CT_LOG_LEVEL_MAX\).*$/\1="EXTRA"/' \
        -e 's/^.*\(CT_LOG_PROGRESS_BAR\).*$/# \1 is not set/' \
        -e 's/^.*\(CT_SAVE_TARBALLS\).*$/\1=y/' \
        "$WORK_DIR/build/.config"
    fi

    # Start building and print dots to keep CI from killing the build due
    # to console inactivity.
    $CTNG $CTNG_BUILD &
    local build_pid=$!
    {
        while ps -p $build_pid >/dev/null; do
           sleep 12
           printf "."
        done
    } &
    local keepalive_pid=$!

    # Wait for the build to finish
    wait $build_pid 2>/dev/null

    # Stop the keepalive task
    kill $keepalive_pid
    wait $keepalive_pid 2>/dev/null || true

    TARGET_TUPLE=$(gcc_tuple)

    echo "Fixing permissions on release"
    # ct-ng likes to mark everything read-only which seems reasonable, but it
    # can be really annoying when trying to cleanup a toolchain.
    chmod -R u+w "$GCC_INSTALL_DIR/$TARGET_TUPLE"

    # Clean up the build product
    rm -f "$GCC_INSTALL_DIR/$TARGET_TUPLE/build.log.bz2"

    # Clean up crosstool-ng's work directory if we put it in a global location
    if [[ "$CI" = "true" ]]; then
        echo "Not cleaning up work directory since CI build"
    else
        if [[ -e "$CT_WORK_DIR" ]]; then
            chmod -R u+w "$CT_WORK_DIR"
            rm -fr "$CT_WORK_DIR"
        fi
    fi
}

save_build_info()
{
    # Save useful information if we ever need to reproduce the toolchain
    TARGET_TUPLE=$(gcc_tuple)
    cp "$SCRIPT_DIR/VERSION" "$GCC_INSTALL_DIR/$TARGET_TUPLE/toolchain-builder.version"
    cp "$CTNG_CONFIG" "$GCC_INSTALL_DIR/$TARGET_TUPLE/ct-ng.defconfig"
    cp "$WORK_DIR/build/.config" "$GCC_INSTALL_DIR/$TARGET_TUPLE/ct-ng.config"
    python3 "$SCRIPT_DIR/scripts/build_info.py" "$SCRIPT_DIR" \
        "$GCC_INSTALL_DIR/$TARGET_TUPLE" "$TOOLCHAIN_NAME" \
        "${HOST_OS}_${ARTIFACT_HOST_ARCH}" "$CTNG_TAG"
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
    TARGET_TUPLE=$(gcc_tuple)
    LINUX_INCLUDE_DIR=$GCC_INSTALL_DIR/$TARGET_TUPLE/$TARGET_TUPLE/sysroot/usr/include/linux
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
    TARGET_TUPLE=$(gcc_tuple)
    bash "$SCRIPT_DIR/scripts/package.sh" "$GCC_INSTALL_DIR/$TARGET_TUPLE" "$OUTPUT_DIR" "${HOST_OS}_${ARTIFACT_HOST_ARCH}"
}

init
build_gcc
finalize_products
build_artifact

echo "Success!"
echo
echo "Generated toolchain: $GCC_INSTALL_DIR."
