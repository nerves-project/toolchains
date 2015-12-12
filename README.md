# nerves-toolchain

This project contains the configuration and scripts used to build the
cross-compilers for the Nerves project. While pre-built toolchains exist for
various hosts and targets, they don't seem to exist for the combination
supported by Nerves. This project fills that gap.

See the GitHub `Releases` tab to download the toolchain. The naming for
toolchains is:

    nerves-toolchain-<gcc tuple>-<host OS>-<host architecture>-<version>.tar.xz

The `gcc tuple` is a standard way of describing a target. The most important parts
are the architecture (e.g., `arm`) and the C Library and ABI (e.g.,
`gnueabihf`). You will receive an error from Nerves if you mix toolchains. The
easy way to decide which toolchain you need is the following:

  * Raspberry Pi Model A+, B, or B+ - `armv6-rpi-linux-gnueabi`
  * Raspberry Pi 2, BBB, and most other ARM boards - `arm-unknown-linux-gnueabihf`

The `host OS` and `host architecture` describe your system. If you're running on
a Mac, this is `Darwin-x86_64`.

When in doubt, use the glibc library toolchains. Almost all code works with the
glibc C library. If you desire the smallest possible target binaries, the musl
toolchain is the way to go. Nerves has been lightly tested against it, but it is
an experimental feature.

## Linux

Install the following packages:

```
sudo apt-get install help2man
```

Run `build_release.sh` and wait.

## OSX

Install the following packages:

```
brew update
brew tap homebrew/dupes
brew install gawk binutils xz wget automake gnu-tar help2man
brew install libtool autoconf gnu-sed mpfr gmp gcc
brew install grep -—with-default-names
brew install --universal gettext
brew link --force gettext

```

Run `build_release.sh` and wait.

## Windows

TBD

## Updating ctng config files

You may need to update the `ctng` configurations if `gcc` needs to be upgraded
or the C library needs to change. The small defconfigs are stored in the
`configs` directory and expanded automatically by `build.sh` to
`work-.../build/.config`. In that directory, you can run `make menuconfig` to
change the `ctng` configuration. When you're done, run `make savedefconfig` and
copy the result to the `configs` directory.

## Toolchain configuration notes

### GCC 4.9.x vs. GCC 5.x

The Nerves toolchains use gcc 4.9.x, since it was found that gcc 5 does
not compile some older Linux kernels that are still in use.

### Hard float vs. soft float

When possible hard float ABI (`eabihf`) toolchains are preferred. This appears to be
the prevaling preference for ARM toolchains, so in the offchance that we need to
run code from a binary blob, this provides the best chance of success.

### Glibc 2.22 / Raspberry Pi userland

Glibc 2.22 has a `#define` change that breaks the Raspberry Pi userland
(rpi-userland) package. You'll get an error that `EAI_AGAIN` and some other
defines are missing due to a `#ifdef` that changed from `__USE_POSIX` to
`_USE_XOPEN2K`. Do *NOT* select glibc 2.22 until `rpi-userland` is fixed.

See https://bugs.busybox.net/show_bug.cgi?id=8446 for more details.

### Case insensitive filesystems

By default, the filesystems used on OSX are case insensitive. To get around
this, we create a case-sensitive filesystem and build the cross-compilers in it.
The build products also require a case-sensitive filesystem IF the user wants to
use the Linux netfilter module. This is currently not a common use case for
Nerves so the header file conflicts are removed in the OSX tarball version. See
`build.sh` for details.

