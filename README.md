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

* `toolchain_builder/` contains the build implementation, flat configurations,
  patches, pinned crosstool-NG revision, and component version metadata.
* `template/` and `generate_toolchains.exs` produce the twelve compatibility
  Mix packages for existing Nerves 1 systems.
* `nerves_toolchain_gcc/` is the generic integration package for Nerves 2.
  Systems select compiler archives in their own configuration instead of
  depending on compiler-version-specific Mix packages. See its
  [README](nerves_toolchain_gcc/README.md).

See the GitHub `Releases` tab to download the toolchain. The naming for
toolchains is:

    <gcc tuple>--gcc-<version>-<libc>-<version>-linux-<headers>--<release>--<host tuple>.tar.xz

For example:

    armv7-nerves-linux-gnueabihf--gcc-15.3.0-glibc-2.43-linux-5.10.258--15.3.1--x86_64-linux-gnu.tar.xz

The release is set in `toolchain_builder/VERSION`. There is no source fingerprint
in the name: bump the release for changes to build inputs, patches, or settings,
even when the component versions stay the same. Published URLs must be immutable.
The builder refuses to replace an existing archive.

The twelve Nerves 1 package templates remain, but compatibility archive aliases
and their release integration are deferred while the native builder is revised.
Those aliases can eventually be copies of the native archives; they do not
require another compiler build.

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

Resolve and validate the explicitly selected component versions:

```sh
make refresh_version_info
```

Build one toolchain on its intended host, without Docker or Nerves:

```sh
./build_one.sh armv7-nerves-linux-gnueabihf--gcc15
```

The argument is a filename from `toolchain_builder/configs/`, without
`.defconfig`. Build state goes in `o/<config name>` and native archives go in
`o/artifacts`. The builder needs Elixir for metadata and configuration checks,
but does not depend on Mix packages or Nerves.

Print the native release metadata, including the archive URL map for a Nerves 2
system, without generating any compatibility packages:

```sh
elixir toolchain_builder/artifact_names.exs armv7-nerves-linux-gnueabihf--gcc15
```

CI builds Linux x86_64, Linux aarch64, and macOS arm64. Release when those builds
and tests finish; other hosts can be built manually from the **same release tag**
and uploaded to that release later. Neither the release identity nor its URLs
depend on which hosts have finished. The URL map describes expected filenames,
not current availability; check the GitHub release assets for available hosts.
Do not overwrite existing release assets. SHA256 manifests remain a future step.

`make generate` still generates the twelve compatibility packages, and `make`
resolves versions and generates them. Publishing their legacy aliases is not
part of the current native release workflow.

Run `make test` for packaging and integration tests and `make check` for package
compilation, documentation, and Hex packaging. Neither command builds a compiler.

If you want to modify the configuration, you can do it via Crosstool-ng's
menuconfig:

```sh
<CTRL-C> out of a running build or "killall make", etc.

$ cd o/armv7-nerves-linux-gnueabihf--gcc15/build
$ ../usr/bin/ct-ng menuconfig

# make modifications

$ ../usr/bin/ct-ng savedefconfig

# merge defconfig changes over to
# toolchain_builder/configs/armv7-nerves-linux-gnueabihf--gcc15.defconfig.
# Keep explicit version selections even if savedefconfig omits them.
# Host settings belong in toolchain_builder/defaults/<platform>_defconfig.
```

## Toolchain configuration notes

### Compiler tracks and explicit versions

Flat configs are named `<target tuple>--<track>.defconfig`. The initial `gcc15`
track selects GCC 15.3.0 and Linux 5.10.258 headers. A newer GCC 16.2 track is
planned, but is not configured until the pinned crosstool-NG supports it.
Additional tracks can coexist as separate files and CI discovers them
automatically.

Keep GCC, binutils, Linux headers, and libc version selections in each config,
including defaults. Both the Kconfig choice (for example `CT_GCC_V_15=y`) and
the resolved version (`CT_GCC_VERSION="15.3.0"`) are explicit. Kconfig can ignore
a non-editable version string, so the updater and builder check the full
resolved `.config` and fail on mismatches instead of silently changing versions.
`savedefconfig` output alone is insufficient because it drops defaults.
The crosstool-NG revision stays pinned separately in `toolchain_builder/config.exs`.

Older compiler/header tracks should still receive current stable glibc and musl
releases for security fixes. These are currently pinned to glibc 2.43 and musl
1.2.6. Update their selections and validate compatibility on both tracks rather
than freezing libc along with GCC.

glibc's minimum runtime kernel is pinned independently to 5.10.0, not to the
headers' patch level. Newer headers do not automatically mean newer syscalls are
available on the running device. Actual runtime support also depends on libc,
the architecture, and application code; config validation is not a device test.

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

