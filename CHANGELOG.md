# Toolchain Releases

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
