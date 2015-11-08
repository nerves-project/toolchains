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

Run `build.sh` and wait.

## OSX

Install the following packages:

```
brew update
brew tap homebrew/dupes
brew install gawk binutils xz wget automake
brew install libtool autoconf gnu-sed mpfr gmp gcc
brew install grep -—with-default-names
brew install --universal gettext
brew link --force gettext

```

Run `build.sh` and wait.

## Windows

TBD

