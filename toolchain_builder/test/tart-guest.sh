#!/bin/sh
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -eu
GUEST=$1
ARCHIVE=$2
FIXTURE=$3

uname -a
case "$GUEST" in
    sequoia|golden-gate)
        sw_vers
        case "$GUEST" in
            sequoia) VERSION=15 ;;
            golden-gate) VERSION=27 ;;
        esac
        test "$(uname -m)" = arm64
        test "$(sw_vers -productVersion | cut -d. -f1)" = "$VERSION"
        ;;
    ubuntu-*|rocky-*)
        cat /etc/os-release
        # shellcheck source=/dev/null
        . /etc/os-release
        test "$ID" = "${GUEST%-*}"
        case "$GUEST" in
            ubuntu-*) test "$VERSION_ID" = "${GUEST#ubuntu-}" ;;
            rocky-*) test "${VERSION_ID%%.*}" = "${GUEST#rocky-}" ;;
        esac
        test "$(uname -m)" = aarch64
        ;;
    *) exit 1 ;;
esac

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$WORK/toolchain"
tar -xJf "$ARCHIVE" --strip-components=1 -C "$WORK/toolchain"
test -f "$WORK/toolchain/ct-ng.config"
set -- "$WORK"/toolchain/bin/*-gcc
if [ "$#" != 1 ] || [ ! -x "$1" ]; then
    echo "Expected one relocatable cross-gcc" >&2
    exit 1
fi
CC=$1
PREFIX=${CC%-gcc}
"$CC" --version
"$PREFIX-g++" --version
"$PREFIX-as" --version
"$PREFIX-ld" --version
printf '#include <stdio.h>\nint main(void) { return puts("C smoke test") < 0; }\n' > "$WORK/main.c"
"$CC" -O2 "$WORK/main.c" -o "$WORK/c.elf"
"$PREFIX-g++" -O2 -g0 -Wl,--build-id=none "$FIXTURE" -o "$WORK/cxx.elf"
"$PREFIX-g++" -O2 -flto "$FIXTURE" -o "$WORK/lto.elf"
if grep -q '^CT_CC_LANG_FORTRAN=y$' "$WORK/toolchain/ct-ng.config"; then
    printf 'program smoke\nprint *, "Fortran smoke test"\nend program smoke\n' > "$WORK/main.f90"
    "$PREFIX-gfortran" "$WORK/main.f90" -o "$WORK/fortran.elf"
fi
if grep -q '^CT_GDB_CROSS=y$' "$WORK/toolchain/ct-ng.config"; then
    "$PREFIX-gdb" -nx -nh -batch -ex 'info files' "$WORK/cxx.elf"
fi
"$PREFIX-readelf" -h "$WORK/c.elf" "$WORK/cxx.elf" "$WORK/lto.elf"
