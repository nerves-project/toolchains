# Nerves Toolchains

This is an umbrella project for all of the Nerves toolchains. Toolchains include
a compiler, C library and some tools for building native code on Nerves devices.
Nerves manages its own cross-compilers so that the exact same versions of GCC
are used on macOS, Linux and all of their variations.

Each toolchain is built using Crosstool-NG and packaged up as an Elixir package.
Since the toolchain packages are so similar, the Elixir packages are generated
from a template rather than maintained elsewhere.

See the GitHub `Releases` tab to download the toolchain. The naming for
toolchains is:

    nerves-toolchain-<gcc tuple>-<host OS>-<host architecture>-<version>.tar.xz

The `gcc tuple` is a standard way of describing a target. The most important parts
are the architecture (e.g., `arm`) and the C Library and ABI (e.g.,
`gnueabihf`). You will receive an error from Nerves if you mix toolchains. The
easy way to decide which toolchain you need is the following:

  * Raspberry Pi Model A+, B, or B+ - `armv6-nerves-linux-gnueabihf`
  * Raspberry Pi 2, BBB, and most other ARM boards - `armv7-nerves-linux-gnueabihf`

The `host OS` and `host architecture` describe your system. If you're running on
a Mac, this is `Darwin-x86_64` or `Darwin-arm64`.

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

First generate the toolchain projects:

```sh
make clean
make
```

The code that generates the projects doesn't delete old files since that's
sometimes convenient. It's safest to run `make clean` first if you're unsure.

Then build one:

```sh
./build_one.sh nerves_toolchain_arm_nerves_linux_gnueabihf
```

This will build the toolchain in the `o/<package>` directory. If you want to
modify the configuration, you can do it via Crosstool-ng's menuconfig:

```sh
<CTRL-C> out of a running build or "killall make", etc.

$ cd o/<package>/build
$ ../usr/bin/ct-ng menuconfig

# make modifications

$ ../usr/bin/ct-ng savedefconfig

# merge defconfig changes over to
# nerves_toolchain_arm_nerves_linux_gnueabihf/defconfig or whatever you're
# building. Some configuration options are platform-specific and should be put
# in nerves_toolchain_ctng/defaults/<platform>
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
`build.sh` for details.

### 64-bit ARM Builds

It's possible to create cross-compilers for 64-bit ARM machines (aarch64) by
building the toolchains on a 64-bit ARM machine. Canadian cross builds don't
seem to work. Build as you would on an x86_64 Linux machine.

NOTE: "`aarch64` for Darwin" is called `arm64`. They're slightly different. See
the [gcc arm64
port](https://github.com/fxcoudert/gcc/tree/gcc-11.2.0-arm#introduction).

