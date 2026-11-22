#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

IMAGE=docker.io/library/ubuntu:22.04
BUILD_IMAGE=nerves-toolchain-builder:ubuntu-22.04
WINDOWS_BUILD_IMAGE=nerves-toolchain-builder:ubuntu-22.04-mingw

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE=/tmp/nerves-toolchain-builder

usage()
{
    echo "Usage: bash build_with_docker.sh <config>"
}

if [[ ${1:-} = --help || ${1:-} = -h ]]; then usage; exit 0; fi
if [[ $# != 1 ]]; then usage >&2; exit 1; fi
CONFIG=$1
if [[ ! $CONFIG =~ ^[A-Za-z0-9][A-Za-z0-9_.+-]*$ || ! -f "$ROOT/configs/$CONFIG.defconfig" ]]; then
    echo "Unknown toolchain config: $CONFIG" >&2
    exit 1
fi
HOST=linux_x86_64
EXTRA_PACKAGES=
if [[ $CONFIG = *--mingw_x86_64 ]]; then
    HOST=mingw_x86_64
    BUILD_IMAGE=$WINDOWS_BUILD_IMAGE
    EXTRA_PACKAGES="gcc-mingw-w64-x86-64-posix g++-mingw-w64-x86-64-posix"
fi
for command in docker timeout sha256sum; do
    if ! command -v "$command" >/dev/null; then
        echo "Missing command: $command (requires Docker and GNU coreutils)" >&2
        exit 1
    fi
done

mkdir -p "$ROOT/o/artifacts" "$ROOT/o/docker-builds"
EXISTING=$(bash "$ROOT/scripts/archive.sh" --find "$ROOT/o/artifacts" "$CONFIG" "$HOST" "$(cat "$ROOT/VERSION")")
if [[ -n "$EXISTING" ]]; then
    (cd "$ROOT/o/artifacts" && sha256sum -- "${EXISTING##*/}" | cmp - "${EXISTING##*/}.sha256")
    echo "Skipping $CONFIG: already built at $EXISTING"
    exit 0
fi
docker info >/dev/null

RUN_DIR=$(mktemp -d "$ROOT/o/docker-builds/run-XXXXXX")
CONTAINER="toolchain-build-${RUN_DIR##*/}"
cleanup()
{
    local status=$?
    if ! timeout --kill-after=5 30 docker rm --force "$CONTAINER" > /dev/null 2>&1; then
        if [[ $status = 0 ]]; then
            echo "Could not remove container: $CONTAINER" >&2
            status=1
        fi
    fi
    echo "Build logs: $RUN_DIR"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir "$RUN_DIR/source" "$RUN_DIR/artifacts"
cp "$ROOT"/{Makefile,VERSION,LICENSE,README.md,build_native.sh} "$RUN_DIR/source/"
cp -R "$ROOT"/{scripts,configs,defaults,patches} "$RUN_DIR/source/"
echo "Building $CONFIG for $HOST in $IMAGE (linux/amd64)"
timeout --kill-after=10 1200 docker build --pull --platform linux/amd64 \
    --build-arg "BASE=$IMAGE" --build-arg "EXTRA_PACKAGES=$EXTRA_PACKAGES" \
    --tag "$BUILD_IMAGE" - > "$RUN_DIR/image.log" 2>&1 <<'DOCKERFILE'
ARG BASE
FROM ${BASE}
ARG EXTRA_PACKAGES
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential bison flex gperf libncurses-dev texinfo help2man \
        libssl-dev gawk libtool-bin automake autoconf lzip unzip python3 wget \
        curl ca-certificates xz-utils zstd openssl git file patch rsync pkg-config \
        bzip2 passwd $EXTRA_PACKAGES && \
    apt-get clean && \
    useradd --create-home --shell /bin/bash builder
ENV HOME=/home/builder
USER builder
DOCKERFILE

docker run -i --name "$CONTAINER" --platform linux/amd64 \
    --mount "type=bind,source=$RUN_DIR/source,target=/source,readonly" \
    "$BUILD_IMAGE" /bin/bash -s -- "$CONFIG" 2>&1 <<'BUILD_SCRIPT' | tee "$RUN_DIR/build.log"
set -euo pipefail
CONFIG=$1
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
WORKSPACE=/tmp/nerves-toolchain-builder
mkdir -p "$WORKSPACE"
tar -C /source -cf - . | tar -C "$WORKSPACE" -xf -
bash "$WORKSPACE/build_native.sh" "$CONFIG" </dev/null
BUILD_SCRIPT

docker cp "$CONTAINER:$WORKSPACE/o/artifacts/." "$RUN_DIR/artifacts"
shopt -s nullglob
artifacts=("$RUN_DIR/artifacts"/*.tar.xz)
if [[ ${#artifacts[@]} != 1 || ${artifacts[0]} != *--"$HOST".tar.xz ]]; then
    echo "Expected one $HOST archive from the container" >&2
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
