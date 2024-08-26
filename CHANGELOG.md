# Toolchain Releases

## v14.2.0

This release bumps GCC from 13.2 to 14.2.

* Tool versions
  * GCC 14.2 (https://gcc.gnu.org/gcc-14/changes.html)
  * glibc 2.40
  * musl 1.2.5

## v13.2.0

This release bumps GCC from 12.2 to 13.2 and adopts the new version scheme that
mirrors GCC versions.

* Changes
  * Re-add static toolchain option since LTO no longer gets turned off when it's
    enabled.
  * Build a multilib toolchain for RISC-V glibc builds to support both 32-bit
    and 64-bit, soft and hard float compilation

* Tool versions
  * GCC 13.2
  * glibc 2.38
  * musl 1.2.4
  * Linux 5.4 headers except for RISC-V. RISC-V uses Linux 5.15 headers.

## v1.8.0

This release bumps GCC from 11.3 to 12.2.

* Tool versions
  * GCC 12.2 (https://gcc.gnu.org/gcc-12/changes.html)
  * glibc 2.36
  * musl 1.2.3
  * Linux 4.19 headers except for RISC-V. RISC-V uses Linux 5.10 headers.

## v1.7.0

This release adds a riscv64 glibc toolchain since that has more support than
muslc in the RISC-V community at the moment.

* Changes
  * Removes Python scripting support in gdb (fixes toolchain compilation and
    probably not used)
  * Remove the static toolchain option since it was being ignored on MacOS. On
    Linux, it disabled LTO. LTO is included on all platforms now (the default).
  * Fixes runtime dependency on libzstd another way by forcibly turning it off
    with a Crosstool-NG option rather than adding a configure flag. This is
    possible now. Previously the option was hidden due to the static toolchain
    option.
  * Let gcc determine the correct option for SJLJ (setjmp/longjmp). The note
    where it doesn't work doesn't apply to Nerves platforms.

* Tool versions
  * GCC 11.3
  * glibc 2.36 (New!)
  * musl 1.2.3
  * Linux 4.19 headers except for RISC-V. RISC-V uses Linux 5.10 headers.

## v1.6.1

This release adds musl libc toolchains for aarch64 and armv7.

* Fixes
  * Remove unneeded runtime dependency on libzstd. This caused an unintentional
    dependency to Homebrew on MacOS.

## v1.6.0

This release bumps GCC from 10.3 to 11.3

* New features
  * Include a Fortran compiler to make it easier to create Nerves systems that
    require Fortran.

* Tool versions
  * GCC 11.3 (https://gcc.gnu.org/gcc-11/changes.html#GCC11.3)
  * glibc 2.35
  * musl 1.2.3
  * binutils 2.38
  * Linux 4.19 headers except for RISC-V. RISC-V uses Linux 5.10 headers.

## v1.5.0

This should be a low risk update to v1.4.3. The main purpose is to make libgomp
available. It remains on GCC 10, but pulls in the latest patch releases of
associated build tools..

* New features
  * libgomp is available now

* Tool versions
  * GCC 10.3 (https://gcc.gnu.org/gcc-10/changes.html#GCC10.3)
  * glibc 2.34 (https://sourceware.org/pipermail/libc-alpha/2021-August/129718.html)
  * binutils 2.37
  * Linux 4.19 headers except for RISC-V. RISC-V uses Linux 5.4 headers.

## v1.4.3

This release bumps the Linux headers from 4.14 to 4.19. This requires that your
Nerves system uses Linux 4.19 or later.

* New features
  * Store a Build-ID by default. A Build-ID uniquely identifies an executable or
    shared library and is useful for matching up debug symbols to produce useful
    stack traces from C and C++ programs.
  * A 64-bit RISC-V crosscompiler is now available.

* Tool versions
  * GCC 10.2
  * Linux 4.19 headers (except for RISC-V)
  * glibc 2.33
  * binutils 2.36.1

## v1.4.2

This release reverts the switch from 4.14 headers to 4.4 headers in v1.4.0. This
re-enables `libgpiod` (cdev), `bluez5`, `iwd`, and `ply` (eBPF) which required
headers after 4.4.

* Fixes
  * ARMv7 toolchain now defaults to "generic-arm-v7a" rather than "cortex-a9".
    This fixes a potential issue of generating invalid ARM instructions, but it
    appears that this did not affect ARM Cortex-A7 and A8 platforms supported by
    Nerves.

* Tool versions
  * GCC 10.2
  * Linux 4.14 headers
  * glibc 2.33
  * binutils 2.36.1

## v1.4.1

This release adds host support for native Mac M1 toolchains.

Hardware float has been enabled on the `armv6` toolchain to further
consistency with https://toolchains.bootlin.com configurations.

* Updated dependencies
  * nerves_toolchain_ctng v1.8.2

## v1.4.0

This release updates gcc from version 9.2.0 to 10.2.0 and includes various
updates to the C runtime. See https://gcc.gnu.org/ for the many changes in the
gcc 10.x releases.

All toolchains have been renamed to set the vendor to nerves. ARM32 toolchains
were renamed for consistency with https://toolchains.bootlin.com naming.

```text
nerves_toolchain_aarch64_unknown_linux_gnu        -> nerves_toolchain_aarch64_nerves_linux_gnu
nerves_toolchain_armv5tejl_unknown_linux_musleabi -> nerves_toolchain_armv5_nerves_linux_musleabi
nerves_toolchain_armv6_rpi_linux_gnueabi          -> nerves_toolchain_armv6_nerves_linux_gnueabi
nerves_toolchain_arm_unknown_linux_gnueabihf      -> nerves_toolchain_armv7_nerves_linux_gnueabihf
nerves_toolchain_i586_unknown_linux_gnu           -> nerves_toolchain_i586_nerves_linux_gnu
nerves_toolchain_mipsel_unknown_linux_musl        -> nerves_toolchain_mipsel_nerves_linux_musl
nerves_toolchain_x86_64_unknown_linux_gnu         -> nerves_toolchain_x86_64_nerves_linux_gnu
nerves_toolchain_x86_64_unknown_linux_musl        -> nerves_toolchain_x86_64_nerves_linux_musl
```

Linux headers were downgraded from 4.14.160 to 4.4.214 to support using
toolchains with systems using older versions of Linux.

* Tool versions
  * GCC 10.2
  * Linux 4.4.214 headers
  * glibc 2.32

* Updated dependencies
  * nerves v1.7
  * nerves_toolchain_ctng v1.8.1

## v1.3.2

This is a patch release that adds support for macOS >=  High Sierra. There is no
reason to update from 1.3.0 if that version works for you.

* Updated dependencies
  * nerves_toolchain_ctng v1.7.2

## v1.3.1

This is a patch release that enables support for 64-bit ARM hosts. There is no
reason to update from 1.3.0 if that version works for you.

* Updated dependencies
  * nerves v1.6.0
  * nerves_toolchain_ctng v1.7.1

## v1.3.0

This release updates gcc from version 8.3.0 to 9.2.0 and includes various
updates to the C runtime. See https://gcc.gnu.org/ for the many changes in the
gcc 9.x releases.

* Tool versions
  * Linux 4.14.160 headers
  * glibc 2.30
  * muslc 1.1.24

* Updated dependencies
  * nerves v1.5
  * nerves_toolchain_ctng v1.7.0

## v1.2.0

This release updates gcc from version 7.3.0 to 8.3.0 and includes various
updates to the C runtime. See https://gcc.gnu.org/ for the many changes in the
gcc 8.x releases.

* Tool versions
  * glibc 2.29
  * muslc 1.1.21

* Updated dependencies
  * nerves v1.4
  * nerves_toolchain_ctng v1.6.0

## v1.1.0

This release upgrades gcc from version 6.3.0 to 7.3.0. This addresses a C++
compiler issue and may bring in performance improvements.

* Tool versions
  * glibc 2.27
  * muslc 1.1.19

* Updated dependencies
  * nerves v1.1
  * nerves_toolchain_ctng v1.5.0

## v1.0.0

* Updated dependencies
  * nerves v1.0
  * nerves_toolchain_ctng v1.4

## v1.0.0-rc.0

* Updated dependencies
  * nerves v1.0-rc
  * nerves_toolchain_ctng v1.4-rc

## v0.13.1

* Enhancements
  * Build static toolchains for Linux to avoid shared library issues

## v0.13.0

* Enhancements
  * Toolchains are now built through `mix compile`
  * Toolchain artifacts can be produced with `mix nerves.artifact`
  * Updated project to support nerves v0.9

## v0.12.1

* Bug Fixes
  * Configure toolchains to build app files. This will fix an issue where Mix
    does not respect `app: false`

## v0.12.0

* Enhancements
  * Updated for nerves 0.8. Moved nerves.exs to mix.exs

## v0.11.0

* Enhancements
  * Bumped all Linux 3.x kernel header configs up to 4.1
  * Build a cross gdb and gdbserver to support crash dump analysis and on
    target debugging of C/C++ code
* Tool versions
  * m4-1.4.18
  * linux-4.1.39
  * gmp-6.1.2
  * mpfr-3.1.5
  * isl-0.18
  * mpc-1.0.3
  * expat-2.2.0
  * ncurses-6.0
  * libiconv-1.15
  * gettext-0.19.8.1
  * binutils-2.28
  * gcc-6.3.0
  * glibc-2.25
  * gdb-7.12.1

## v0.10.1

* Enhancements
  * Update nerves to 0.7
  * Fix compiler warnings for Elixir 1.5

## v0.10.0

* Enhancements
  * Updated nerves to 0.5.0 and loosened dep lock
  * Update linux header patch for 4.4

## v0.9.0

* New features
  * Bump gcc version from 4.9 to 5.3 - THIS BREAKS COMPILATION OF OLD LINUX
    KERNELS! If you have no choice but to use an old Linux kernel, please
    do not upgrade to this toolchain.
  * Added x86_64 toolchain that's built against glibc

## v0.8.0

* New features
  * Refactored defconfigs so that platform-independent and platform-dependent
    parts are stored separately. This majorly simplifies maintenance.
  * Added support for the `:nerves_package` compiler

## v0.7.2

### armv6_rpi_linux_gnueabi

* Bug Fixes
  * [darwin] fixed defconfig to use 3.12 linux kernel headers

## v0.7.1

* New features
  * First release using combined toolchain repository
