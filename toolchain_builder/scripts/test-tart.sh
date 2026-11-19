#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

# This script runs a smoke test on toolchains that run on ARM64 using Tart.
# This only works on Apple Silicon.
#
# Run `brew install openai/tools/tart` to install Tart. More instructions are
# at https://tart.run/quick-start/.
#
set -euo pipefail

# Supported Tart images for testing toolchains.
GUEST_IMAGES="${GUEST_IMAGES:-"
ghcr.io/cirruslabs/macos-sequoia-base:latest
ghcr.io/cirruslabs/macos-golden-gate-base:latest
ghcr.io/cirruslabs/ubuntu:22.04
ghcr.io/cirruslabs/ubuntu:24.04
ghcr.io/cirruslabs/rocky:9
"}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARE=/tmp/nerves-toolchain-tests

usage()
{
    echo "Usage: bash scripts/test-tart.sh <archive.tar.xz|all> [artifact directory]"
}

if [[ ${1:-} = --help || ${1:-} = -h ]]; then usage; exit 0; fi
if [[ $# -lt 1 || $# -gt 2 ]]; then usage >&2; exit 1; fi
if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
    echo "Tart validation requires an Apple Silicon Mac" >&2
    exit 1
fi
TIMEOUT=timeout
if command -v gtimeout >/dev/null; then TIMEOUT=gtimeout; fi
for command in tart "$TIMEOUT" sha256sum; do
    if ! command -v "$command" >/dev/null; then
        echo "Missing command: $command (requires Tart and GNU coreutils)" >&2
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
HAS_MAC=false
HAS_LINUX=false
for archive in ${archives[@]+"${archives[@]}"}; do
    case "$archive" in
        *--darwin_arm.tar.xz) HAS_MAC=true ;;
        *--linux_aarch64.tar.xz) HAS_LINUX=true ;;
        *)
            if [[ $1 != all ]]; then
                echo "Expected a darwin_arm or linux_aarch64 archive: $archive" >&2
                exit 1
            fi
            echo "SKIP ${archive##*/}: not a native ARM64 host archive"
            continue
            ;;
    esac
    (cd "$ARCHIVE_DIR" && sha256sum -- "${archive##*/}" | cmp - "${archive##*/}.sha256")
done
if ! $HAS_MAC && ! $HAS_LINUX; then
    echo "No compatible toolchain archives found" >&2
    exit 1
fi

mkdir -p "$ROOT/o/tart-tests" "$ROOT/o/tmp"
export TART_HOME="$ROOT/o/tart-tests/tart" TMPDIR="$ROOT/o/tmp" TART_NO_AUTO_PRUNE=1
RUN_DIR=$(mktemp -d "$ROOT/o/tart-tests/run-XXXXXX")
VM=
PID=
BOOT_LOG=/dev/null

cleanup()
{
    if [[ -n "$PID" ]]; then
        if kill -0 "$PID" 2>/dev/null; then
            if ! "$TIMEOUT" 15 tart stop --timeout 5 "$VM" >> "$BOOT_LOG" 2>&1; then
                kill -KILL "$PID" 2>/dev/null || true
            fi
        fi
        wait "$PID" 2>/dev/null || true
        PID=
    fi
    if [[ -n "$VM" ]]; then
        "$TIMEOUT" 60 tart delete "$VM" >> "$BOOT_LOG" 2>&1 || return 1
        VM=
    fi
}

trap 'status=$?; cleanup || status=1; echo "Results: $RUN_DIR"; exit "$status"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if ! $HAS_MAC; then echo "SKIP macOS guests: no darwin_arm archives"; fi
if ! $HAS_LINUX; then echo "SKIP Linux guests: no linux_aarch64 archives"; fi

test_guest()
{
    local guest=$1 image=$2 host=$3 mount name deadline archive test_log outcome status=0
    name="toolchain-test-${RUN_DIR##*/}-$guest"
    BOOT_LOG="$RUN_DIR/$guest-vm.log"
    echo "Starting $guest: $image"
    "$TIMEOUT" 3600 tart pull "$image" > "$BOOT_LOG" 2>&1 || return 1
    "$TIMEOUT" 3600 tart clone "$image" "$name" >> "$BOOT_LOG" 2>&1 || return 1
    VM=$name
    tart run "$VM" --no-graphics \
        --dir "archives:$ARCHIVE_DIR:ro,tag=nerves-toolchains" \
        --dir "tests:$ROOT/test:ro,tag=nerves-toolchains" >> "$BOOT_LOG" 2>&1 &
    PID=$!
    deadline=$((SECONDS + 300))
    until "$TIMEOUT" 10 tart exec "$VM" /usr/bin/true >/dev/null 2>&1; do
        if ! kill -0 "$PID" 2>/dev/null || [[ $SECONDS -ge $deadline ]]; then
            echo "VM exited or its guest agent did not become ready" >> "$BOOT_LOG"
            return 1
        fi
        sleep 2
    done
    if [[ $host = linux_aarch64 ]]; then
        mount="sudo -n mount -t virtiofs nerves-toolchains"
    else
        mount="sudo -n /sbin/mount_virtiofs nerves-toolchains"
    fi
    "$TIMEOUT" 60 tart exec "$VM" /bin/sh -ec "mkdir -p $SHARE; $mount $SHARE" \
        >> "$BOOT_LOG" 2>&1 || return 1
    for archive in "${archives[@]}"; do
        [[ $archive = *--"$host".tar.xz ]] || continue
        test_log="$RUN_DIR/$guest--${archive##*/}.log"
        if "$TIMEOUT" 300 tart exec "$VM" /usr/bin/env -i \
            PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C TMPDIR=/tmp \
            /bin/sh "$SHARE/tests/tart-guest.sh" "$guest" \
            "$SHARE/archives/${archive##*/}" "$SHARE/tests/smoketest/main.cpp" > "$test_log" 2>&1; then
            outcome=PASS
        else
            outcome=FAIL
            status=1
        fi
        printf '%s\t%s\t%s\n' "$outcome" "$guest" "${archive##*/}" \
            | tee -a "$RUN_DIR/results.tsv" || return 1
    done
    return "$status"
}

RESULT=0
for image in $GUEST_IMAGES; do
    case "$image" in
        */ubuntu:*|*/rocky:*)
            $HAS_LINUX || continue
            guest=${image##*/}
            guest=${guest/:/-}
            host=linux_aarch64
            ;;
        */macos-*-base:*)
            $HAS_MAC || continue
            guest=${image##*/macos-}
            guest=${guest%-base:*}
            host=darwin_arm
            ;;
        *)
            echo "Unsupported guest image: $image" >&2
            exit 1
            ;;
    esac
    if ! test_guest "$guest" "$image" "$host"; then
        printf 'FAIL\t%s\tSee guest logs\n' "$guest" | tee -a "$RUN_DIR/results.tsv"
        RESULT=1
    fi
    cleanup || exit 1
done
exit "$RESULT"
