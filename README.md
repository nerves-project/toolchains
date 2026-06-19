# Nerves Toolchains

This is an umbrella project for all of the Nerves toolchains.

## Template System

This repository uses a template system to generate toolchain packages. Each toolchain package embeds the `nerves_toolchain_ctng` code directly instead of depending on it as an external package. This eliminates duplication and avoids dependency versioning conflicts.

- **Template**: See the `template/` directory for the template files
- **Configs**: See the `configs/` directory for per-toolchain configuration files (defconfig, VERSION, LICENSE)
- **Generator**: `generate_toolchains.exs` contains the configuration and generator code
- **Generation**: Run `make generate` to create all toolchain packages from the template
- **Documentation**: See [template/README.md](template/README.md) for details

The toolchain package directories are **generated** and not stored in the repository. Run `make generate` to create them locally with all necessary files.

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

NOTE: "`aarch64` for Darwin" is called `arm64`. They're slightly different. See
the [gcc arm64
port](https://github.com/fxcoudert/gcc/tree/gcc-11.2.0-arm#introduction).

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