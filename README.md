<!--
SPDX-FileCopyrightText: 2026 Frank Hunleth
SPDX-License-Identifier: CC-BY-4.0
-->

# Nerves Toolchains

This is an umbrella project for all of the Nerves toolchains. Toolchains include
a compiler, C library and some tools for building native code on Nerves devices.
Nerves manages its own cross-compilers so that the exact same versions of GCC
are used on macOS, Linux and all of their variations.

Toolchains are built natively using crosstool-NG, outside of Nerves:

* `toolchain_builder/` contains the build implementation, configurations,
  patches, pinned crosstool-NG revision, and component version metadata.
* `template/` and `generate_toolchains.exs` produce the twelve compatibility
  Mix packages for existing Nerves 1 systems.
* `nerves_toolchain_gcc/` is the generic integration package for Nerves 2.
  Systems select compiler archives in their own configuration instead of
  depending on compiler-version-specific Mix packages. See its
  [README](nerves_toolchain_gcc/README.md).

See the GitHub `Releases` tab to download the toolchain. The naming for
toolchains is:

    <gcc tuple>--<version>-<source fingerprint>--<host tuple>.tar.xz

The builder also publishes byte-identical copies with the legacy
`nerves_toolchain_<target>-<legacy host>-<version>-<package fingerprint>.tar.xz`
names. Nerves 1 derives those names from package metadata, so these aliases
preserve compatibility without requiring another compiler build.

The `gcc tuple` is a standard way of describing a target. The most important parts
are the architecture (e.g., `arm`) and the C Library and ABI (e.g.,
`gnueabihf`). You will receive an error from Nerves if you mix toolchains. The
easy way to decide which toolchain you need is the following:

  * Raspberry Pi Model A+, B, or B+ - `armv6-nerves-linux-gnueabihf`
  * Raspberry Pi 2, BBB, and most other ARM boards - `armv7-nerves-linux-gnueabihf`

The host tuple identifies the computer running the compiler: `x86_64-linux-gnu`,
`aarch64-linux-gnu`, `x86_64-apple-darwin`, or `aarch64-apple-darwin`.

When in doubt, use the glibc library toolchains. Almost all code works with the
glibc C library. If you desire the smallest possible target binaries, the musl
toolchain is the way to go.

## Installation

On Linux, install the following packages:

```sh
sudo apt install build-essential bison flex gperf libncurses5-dev texinfo help2man libssl-dev gawk libtool-bin automake lzip unzip python3 wget curl ca-certificates
```

On macOS, install the following packages:

```sh
brew update
brew install gawk binutils xz wget automake gnu-tar help2man bash make ncurses libtool autoconf gnu-sed mpfr gmp gcc bison lzip python3 grep coreutils texinfo
```

## Building

Builds can take a very long time especially when building all toolchains.

Resolve component versions and generate the compatibility packages:

```sh
make
```

Build one toolchain on its intended host, without Docker or Nerves:

```sh
./build_one.sh nerves_toolchain_armv7_nerves_linux_gnueabihf
```

Build state goes in `o/<package>` and native archives plus compatibility aliases
go in `o/artifacts`. The builder needs Elixir for metadata and configuration
checks, but does not depend on Mix packages or Nerves.

Use `make generate` to regenerate compatibility packages without resolving
component versions. Each package includes `toolchain.exs`, the native archive
selection that can also be copied into a Nerves 2 system. Publish the native
archives and compatibility aliases before publishing the corresponding Hex
packages. SHA256 manifests remain a future step; source fingerprints are not
cryptographic verification of downloaded artifacts.

Run `make test` for packaging and integration tests and `make check` for package
compilation, documentation, and Hex packaging. Neither command builds a compiler.

If you want to modify the configuration, you can do it via Crosstool-ng's
menuconfig:

```sh
<CTRL-C> out of a running build or "killall make", etc.

$ cd o/<package>/build
$ ../usr/bin/ct-ng menuconfig

# make modifications

$ ../usr/bin/ct-ng savedefconfig

# merge defconfig changes over to
# toolchain_builder/configs/nerves_toolchain_armv7_nerves_linux_gnueabihf/defconfig
# building. Some configuration options are platform-specific and should be put
# in toolchain_builder/defaults/<platform>
```

## Toolchain configuration notes

### Hard float vs. soft float

When possible hard float ABI (`eabihf`) toolchains are preferred. This appears to be
the prevaling preference for ARM toolchains, so in the offchance that we need to
run code from a binary blob, this provides the best chance of success. For ARM
processors that don't have hardware floating point instructions, use the `eabi`
versions of the ARM toolchain.

### Case insensitive filesystems

By default, the filesystems used on OSX are case insensitive. To get around
this, we create a case-sensitive filesystem and build the cross-compilers in it.
The build products also require a case-sensitive filesystem IF the user wants to
use the Linux netfilter module. This is currently not a common use case for
Nerves so the header file conflicts are removed in the OSX tarball version. See
`toolchain_builder/build.sh` for details.

### 64-bit ARM Builds

It's possible to create cross-compilers for 64-bit ARM machines (aarch64) by
building the toolchains on a 64-bit ARM machine. Canadian cross builds don't
seem to work. Build as you would on an x86_64 Linux machine.

NOTE: "`aarch64` for Darwin" is called `arm64`. They're slightly different. See
the [gcc arm64
port](https://github.com/fxcoudert/gcc/tree/gcc-11.2.0-arm#introduction).

