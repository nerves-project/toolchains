# nerves-toolchain

This project contains the configuration and scripts used to build the
cross-compilers for the Nerves project. While pre-built toolchains exist for
various hosts and targets, they don't seem to exist for the combination
supported by Nerves. This project fills that gap.

## Linux

Install the following packages:

```
sudo apt-get install TBD
```

Run `build_release.sh` and wait.

## OSX

Install the following packages:

```
brew update
brew tap homebrew/dupes
brew install gawk binutils xz wget automake gnu-tar
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

