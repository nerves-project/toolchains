#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# These are the official build images so that the toolchains don't use new
# syscalls that everyone doesn't have yet.
MACOS_IMAGE=ghcr.io/cirruslabs/macos-sequoia-base:latest
LINUX_IMAGE=ghcr.io/cirruslabs/ubuntu:22.04

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE=/tmp/nerves-toolchain-build
WORKSPACE=/tmp/nerves-toolchain-builder

usage()
{
    echo "Usage: bash build_with_tart.sh <macos|linux> <config>"
}

if [[ ${1:-} = --help || ${1:-} = -h ]]; then usage; exit 0; fi
if [[ $# != 2 ]]; then usage >&2; exit 1; fi
GUEST=$1
CONFIG=$2
if [[ ! $CONFIG =~ ^[A-Za-z0-9][A-Za-z0-9_.+-]*$ || ! -f "$ROOT/configs/$CONFIG.defconfig" ]]; then
    echo "Unknown toolchain config: $CONFIG" >&2
    exit 1
fi
if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
    echo "Tart builds require an Apple Silicon Mac" >&2
    exit 1
fi
case "$GUEST" in
    linux)
        IMAGE=$LINUX_IMAGE
        HOST=linux_aarch64
        ;;
    macos)
        IMAGE=$MACOS_IMAGE
        HOST=darwin_arm
        ;;
    *) usage >&2; exit 1 ;;
esac
TIMEOUT=timeout
if command -v gtimeout >/dev/null; then TIMEOUT=gtimeout; fi
for command in tart "$TIMEOUT" sha256sum; do
    if ! command -v "$command" >/dev/null; then
        echo "Missing command: $command (requires Tart and GNU coreutils)" >&2
        exit 1
    fi
done

mkdir -p "$ROOT/o/artifacts" "$ROOT/o/tart-builds" "$ROOT/o/tmp"
EXISTING=$(bash "$ROOT/scripts/archive.sh" --find "$ROOT/o/artifacts" "$CONFIG" "$HOST" "$(cat "$ROOT/VERSION")")
if [[ -n "$EXISTING" ]]; then
    (cd "$ROOT/o/artifacts" && sha256sum -- "${EXISTING##*/}" | cmp - "${EXISTING##*/}.sha256")
    echo "Skipping $CONFIG: already built at $EXISTING"
    exit 0
fi

export TART_HOME="${TART_HOME:-"$ROOT/o/tart-tests/tart"}" TMPDIR="$ROOT/o/tmp" TART_NO_AUTO_PRUNE=1
RUN_DIR=$(mktemp -d "$ROOT/o/tart-builds/run-XXXXXX")
VM="toolchain-build-${RUN_DIR##*/}"
PID=
CLONED=false
cleanup()
{
    local status=$?
    if [[ -n "$PID" ]]; then
        if kill -0 "$PID" 2>/dev/null; then
            if ! "$TIMEOUT" 15 tart stop --timeout 5 "$VM" >> "$RUN_DIR/vm.log" 2>&1; then
                kill -KILL "$PID" 2>/dev/null || true
            fi
        fi
        wait "$PID" 2>/dev/null || true
    fi
    if $CLONED; then
        "$TIMEOUT" 60 tart delete "$VM" >> "$RUN_DIR/vm.log" 2>&1 || status=1
    fi
    echo "Build logs: $RUN_DIR"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir "$RUN_DIR/source" "$RUN_DIR/artifacts"
cp "$ROOT"/{Makefile,VERSION,LICENSE,README.md,build.sh} "$RUN_DIR/source/"
cp -R "$ROOT"/{scripts,configs,defaults,patches} "$RUN_DIR/source/"
echo "Building $CONFIG in $IMAGE"
"$TIMEOUT" 3600 tart pull "$IMAGE"
"$TIMEOUT" 3600 tart clone "$IMAGE" "$VM"
CLONED=true
tart set "$VM" --cpu 4 --memory 8192 --disk-size 100
tart run "$VM" --no-graphics --dir "$RUN_DIR/source:ro,tag=nerves-build" > "$RUN_DIR/vm.log" 2>&1 &
PID=$!
deadline=$((SECONDS + 300))
until "$TIMEOUT" 10 tart exec "$VM" /usr/bin/true >/dev/null 2>&1; do
    if ! kill -0 "$PID" 2>/dev/null || [[ $SECONDS -ge $deadline ]]; then
        echo "VM exited or its guest agent did not become ready; see $RUN_DIR/vm.log" >&2
        exit 1
    fi
    sleep 2
done
if [[ $HOST = darwin_arm ]]; then
    mount="sudo -n /sbin/mount_virtiofs nerves-build"
else
    mount="sudo -n mount -t virtiofs nerves-build"
fi
tart exec "$VM" /bin/sh -ec "mkdir -p $SHARE; $mount $SHARE"
tart exec -i "$VM" sudo -n -iu admin /bin/bash -s -- "$CONFIG" 2>&1 <<'GUEST_SCRIPT' | tee "$RUN_DIR/build.log"
set -euo pipefail
CONFIG=$1
WORKSPACE=/tmp/nerves-toolchain-builder
mkdir -p "$WORKSPACE"
tar -C /tmp/nerves-toolchain-build -cf - . | tar -C "$WORKSPACE" -xf -
case "$(uname -s)" in
    Darwin)
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
        export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
        brew install python3 gawk binutils xz zstd wget automake gnu-tar help2man \
            bash make ncurses libtool autoconf gnu-sed gcc@16 bison m4 lzip grep \
            coreutils texinfo gettext </dev/null
        PATH="$(brew --prefix gcc@16)/bin:$PATH"
        SDKROOT="$(xcrun --show-sdk-path)"
        export SDKROOT
        sw_vers
        xcrun --show-sdk-version
        ;;
    Linux)
        sudo -n apt-get update </dev/null
        sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            build-essential bison flex gperf libncurses-dev texinfo help2man \
            libssl-dev gawk libtool-bin automake autoconf lzip unzip python3 wget \
            curl ca-certificates xz-utils zstd openssl git file patch rsync pkg-config </dev/null
        ;;
    *) echo "Unsupported guest OS" >&2; exit 1 ;;
esac
bash "$WORKSPACE/build.sh" "$CONFIG" </dev/null
GUEST_SCRIPT

tart exec "$VM" tar -C "$WORKSPACE/o/artifacts" -cf - . | tar -C "$RUN_DIR/artifacts" -xf -
shopt -s nullglob
artifacts=("$RUN_DIR/artifacts"/*.tar.xz)
if [[ ${#artifacts[@]} != 1 || ${artifacts[0]} != *--"$HOST".tar.xz ]]; then
    echo "Expected one $HOST archive from the guest" >&2
    exit 1
fi
archive=${artifacts[0]}
(cd "$RUN_DIR/artifacts" && sha256sum -- "${archive##*/}" | cmp - "${archive##*/}.sha256")
if [[ -e "$ROOT/o/artifacts/${archive##*/}" || -e "$ROOT/o/artifacts/${archive##*/}.sha256" ]]; then
    echo "Archive or checksum already exists: $ROOT/o/artifacts/${archive##*/}" >&2
    exit 1
fi
ln "$archive" "$ROOT/o/artifacts/${archive##*/}"
ln "$archive.sha256" "$ROOT/o/artifacts/${archive##*/}.sha256"
echo "Native archive: $ROOT/o/artifacts/${archive##*/}"
