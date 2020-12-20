# Nerves Toolchains

This is an umbrella project for all of the Nerves toolchains.

See the subdirectories for the actual toolchains and the `nerves_toolchain_ctng`
directory for the build scripts.

## Installation

See [nerves_toolchain_ctng/README.md](nerves_toolchain_ctng/README.md) for
preparing your system for building the toolchains.

## Building

The normal procedure is to run `./build_release.sh` to build everything or go to
one of the toolchain subdirectories to build the toolchain. This process uses
`mix`. Sometimes bringing in Elixir obfuscates the build process. To build
manually, run something like:

```sh
./nerves_toolchain_ctng/build.sh nerves_toolchain_arm_nerves_linux_gnueabihf/defconfig work
```

This will build the toolchain in the `work` directory. If you want to modify the
configuration, you can do it via Crosstool-ng's menuconfig:

```sh
<CTRL-C> out of a running build or "killall make", etc.

$ cd work/build
$ ../usr/bin/ct-ng menuconfig

# make modifications

$ ../usr/bin/ct-ng savedefconfig

# merge defconfig changes over to
# nerves_toolchain_arm_nerves_linux_gnueabihf/defconfig or whatever you're
# building. Some configuration options are platform-specific and should be put
# in nerves_toolchain_ctng/defaults/<platform>
```

## 64-bit ARM Builds

It's possible to create cross-compilers for 64-bit ARM machines (aarch64) by
building the toolchains on a 64-bit ARM machine. Canadian cross builds don't
seem to work. Build as you would on an x86_64 Linux machine.

## Canadian cross builds for Raspberry Pi (arm)

It's possible to build a toolchain that runs on the Raspberry Pi on x86 Linux.
This is called a Canadian-cross. To do so, first clone the Raspberry Pi
cross-toolchain:

```sh
git clone git://github.com/raspberrypi/tools.git
```

Then run a toolchain build as follows:

```sh
export HOST_OS=linux
export HOST_ARCH=arm
export PATH=<path to tools>/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin
./nerves_toolchain_ctng/build.sh <toolchain/defconfig> <build_dir>
```

## Canadian cross builds for Windows

```sh
sudo apt install g++-mingw-w64-x86-64
```

Then

```sh
export HOST_OS=mingw32
./nerves_toolchain_ctng/build.sh <toolchain/defconfig> <build_dir>
```
