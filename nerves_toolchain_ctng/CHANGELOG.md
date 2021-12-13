# Changelog

## v1.8.5

This release bumps gcc 10.2.0 to gcc 10.3.0.

* Changes
  * Use latest crosstool-ng commit. This also updates glibc from 2.33 to 2.34.
  * Build libgomp. This is a small library that's referenced by torchx.
  * Fix build error on MacOS 12

## v1.8.4

* New features
  * Store a Build-ID by default. A Build-ID uniquely identifies an executable or
    shared library and is useful for matching up debug symbols to produce useful
    stack traces from C and C++ programs.

* Bug fixes
  * Support GCC 11 builds on OSX (Homebrew now installs gcc-11)
  * Fix various issues to support OSX-based CI builds. OSX CI builds are not
    supported yet.

## v1.8.3

This release bumps crosstool-ng to the latest to pull in glibc 2.33.

## v1.8.2

* Enhancements
  * Added support for Darwin ARM64 builds.

## v1.8.1

* Bug fixes
  * Update crosstool-ng git commit. This fixes issues with building the aarch64
    crosscompiler on macOS x86_64 host.

## v1.8.0

This release bumps gcc 9.2.0 to gcc 10.2.0.

* Enhancements
  * Update crosstool-ng git commit. This pulls in gcc 10.2 support and
    a variety of C library and related version bumps.
  * Update macOS build homebrew paths to latest versions.
  * Update toolchain vendor to `nerves` in default defconfigs.

## v1.7.2

* Bug fixes
  * Update macOS homebrew paths for dependencies.

## v1.7.1

* Enhancements
  * 64-bit ARM host builds (aarch64) are now possible. They must be built on
    64-bit ARM machines. Canandian cross versions aren't supported.

## v1.7.0

This release bumps gcc 8.3.0 to gcc 9.2.0.

* Enhancements
  * Update crosstool-ng to latest git commit. This pulls in gcc 9.2 support and
    a variety of C library and related version bumps.

* Bug fixes
  * Fixed a variety of build issues on Linux, OSX, and CI. If you're building
    your own toolchains, you may want to review commits to see what has changed.

## v1.6.0

* Enhancements
  * Update crosstool-ng to crosstool-ng-1.24.0-rc3. This pulls in many updates
    including a bump from gcc 7.3.0 to gcc 8.3.0.

## v1.5.0

* Enhancements
  * Update crosstool-ng to latest to use gcc 7.3.0. This addresses a C++
    compiler issue and may bring in performance improvements.
  * Update build scripts to throw errors when configurations are out of sync
    so that if crosstool-ng drops any options, we definitely know. The checks
    are currently pretty strict (config option order matters, for example)
    since the pain from silent option drops was so great.

* Bug fixes
  * Ensure that all toolchains are static

## v1.4.0

* Updated dependencies
  * nerves v1.0

## v1.3.1

* Enhancements
  * Build static toolchains for Linux to avoid shared library issues

## v1.3.0

* Enhancements
  * Support for nerves v0.9.0

## v1.2.1

* Bug Fixes
  * Build app file to fix issue with Mix compilers not respecint `app: false`

## v1.0.0

* Enhancements
  * Fix compiler warnings for Elixir 1.5

## v0.9.0

* Enhancements
  * Support for gcc 5

## v0.8.0

* Enhancements
  * Support for package compiler

## v0.6.3

* New features
  * Support MIPS 24KEc processors

* Tool versions
  * gcc 4.9.3
  * glibc 2.21
  * muslc 1.1.14 (MIPS-only)

## v0.6.1

* New features
  * Support for ARM processors w/o floating point (ARM926)

## v0.6.0

This version removes Erlang and Elixir from the toolchain. While this was
convenient for creating repeatable builds, differences between Linux
distributions were great enough that multiple versions would need to be made
just for Linux. Aside from this, the versions made here could not easily be
used in nerves-system-br builds and most users had sufficiently compatible
versions of Erlang already. Bakeware will be responsible for matching versions
exactly and nerves-system-br will be responsible for providing errors and
warnings when host/target Erlang and Elixir versions do not match.

* Tool versions
  * gcc 4.9.3
  * glibc 2.21

## v0.5.0

* Tool versions
  * gcc 4.9.3
  * glibc 2.21
  * erlang 18.1
  * elixir 1.2.0

* New features
  * Support for x86 platforms (Galileo, Edison, etc.)

* Fixes
  * Tweak release naming especially to put things in lowercase

## v0.4.0

* Tool versions
  * gcc 4.9.3
  * glibc 2.21
  * erlang 18.1
  * elixir 1.1.1

* New features
  * No more .dmg files on OSX - case conflicts removed (see README.md)

* Fixes
  * Standardize release naming
  * Fix OSX filename (the host OS was incorrectly labelled as linux)

## 0.3

* Tool versions
  * gcc 4.9.3
  * glibc 2.21
  * erlang 18.1
  * elixir 1.1.1

* New features
  * Raspberry Pi A+/B+ crosscompiler (armv6)
