#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

CONTAINER_IMAGES="${CONTAINER_IMAGES:-"
docker.io/library/ubuntu:22.04
docker.io/library/ubuntu:24.04
docker.io/library/alpine:3.24
"}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage()
{
    echo "Usage: bash scripts/test-container.sh <archive.tar.xz|all> [artifact directory]"
}

if [[ ${1:-} = --help || ${1:-} = -h ]]; then usage; exit 0; fi
if [[ $# -lt 1 || $# -gt 2 ]]; then usage >&2; exit 1; fi
for command in docker timeout sha256sum; do
    if ! command -v "$command" >/dev/null; then
        echo "Missing command: $command (requires Docker and GNU coreutils)" >&2
        exit 1
    fi
done

shopt -s nullglob
if [[ $1 = all ]]; then
    ARCHIVE_DIR="$(cd "${2:-"$ROOT/o/artifacts"}" && pwd)"
    archives=("$ARCHIVE_DIR"/*.tar.xz)
else
    if [[ $# != 1 ]]; then usage >&2; exit 1; fi
    ARCHIVE_DIR="$(cd "$(dirname "$1")" && pwd)"
    archives=("$ARCHIVE_DIR/$(basename "$1")")
fi
HAS_LINUX=false
for archive in ${archives[@]+"${archives[@]}"}; do
    if [[ $archive != *--linux_x86_64.tar.xz ]]; then
        if [[ $1 != all ]]; then
            echo "Expected a linux_x86_64 archive: $archive" >&2
            exit 1
        fi
        echo "SKIP ${archive##*/}: not an x86_64 Linux host archive"
        continue
    fi
    HAS_LINUX=true
    (cd "$ARCHIVE_DIR" && sha256sum -- "${archive##*/}" | cmp - "${archive##*/}.sha256")
done
if ! $HAS_LINUX; then
    echo "No compatible toolchain archives found" >&2
    exit 1
fi
docker info >/dev/null

mkdir -p "$ROOT/o/container-tests"
RUN_DIR=$(mktemp -d "$ROOT/o/container-tests/run-XXXXXX")
CONTAINER=
cleanup_container()
{
    if [[ -n "$CONTAINER" ]]; then
        timeout --kill-after=5 15 docker rm --force "$CONTAINER" >/dev/null 2>&1 || true
        CONTAINER=
    fi
}
RESULT=0
trap 'RESULT=$?; cleanup_container; echo "Results: $RUN_DIR"; exit "$RESULT"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for image in $CONTAINER_IMAGES; do
    case "$image" in
        */ubuntu:*|*/alpine:*)
            guest=${image##*/}
            guest=${guest/:/-}
            ;;
        *)
            echo "Unsupported container image: $image" >&2
            exit 1
            ;;
    esac
    local_image="nerves-toolchain-test:$guest"
    echo "Preparing $guest: $image"
    if ! timeout --kill-after=10 1200 docker build --pull --platform linux/amd64 \
        --build-arg "BASE=$image" --tag "$local_image" - > "$RUN_DIR/$guest-image.log" 2>&1 <<'DOCKERFILE'
ARG BASE
FROM ${BASE}
RUN . /etc/os-release && \
    case "$ID" in \
        ubuntu) apt-get update && \
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xz-utils && \
            apt-get clean ;; \
        alpine) apk add --no-cache xz ;; \
        *) exit 1 ;; \
    esac
DOCKERFILE
    then
        printf 'FAIL\t%s\tSee image logs\n' "$guest" | tee -a "$RUN_DIR/results.tsv"
        RESULT=1
        continue
    fi
    for archive in "${archives[@]}"; do
        [[ $archive = *--linux_x86_64.tar.xz ]] || continue
        CONTAINER="toolchain-test-${RUN_DIR##*/}-$guest"
        test_log="$RUN_DIR/$guest--${archive##*/}.log"
        if timeout --kill-after=10 300 docker run --rm --name "$CONTAINER" \
            --platform linux/amd64 --network none --user "$(id -u):$(id -g)" \
            --mount "type=bind,source=$ARCHIVE_DIR,target=/archives,readonly" \
            --mount "type=bind,source=$ROOT/scripts,target=/scripts,readonly" \
            "$local_image" /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin \
            LC_ALL=C TMPDIR=/tmp HOME=/tmp \
            /bin/sh /scripts/toolchain-guest.sh "$guest" "/archives/${archive##*/}" \
            /scripts/smoketest/main.cpp x86_64 > "$test_log" 2>&1; then
            outcome=PASS
        else
            outcome=FAIL
            RESULT=1
        fi
        cleanup_container
        printf '%s\t%s\t%s\n' "$outcome" "$guest" "${archive##*/}" \
            | tee -a "$RUN_DIR/results.tsv"
    done
done
exit "$RESULT"
