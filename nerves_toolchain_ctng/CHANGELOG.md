# Changelog

## v1.5.0-rc.3

This adds a check that toolchain defconfigs are applied cleanly.

* Bug fixes
  * Ensure that all toolchains are static

## v1.5.0-rc.2

* Bug fixes
  * Fix typo in archive script from rc.1

## v1.5.0-rc.1

* Bug fixes
  * Pull in arm_acle.h fix to address compiler errors when building Qt
  * Fix directory path inside of generated tarball

## v1.5.0-rc.0

* Enhancements
  * Update crosstool-ng to latest to use gcc 7.3.0. This addresses a C++
    compiler issue and may bring in performance improvements.

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
