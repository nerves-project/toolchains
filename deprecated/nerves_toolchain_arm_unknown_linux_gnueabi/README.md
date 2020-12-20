# Nerves Toolchain: arm_nerves_linux_gnueabi

[![Hex version](https://img.shields.io/hexpm/v/nerves_toolchain_arm_nerves_linux_gnueabi.svg "Hex version")](https://hex.pm/packages/nerves_toolchain_arm_nerves_linux_gnueabi)

This is a Nerves Toolchain repository.

If you're just trying to use Nerves (i.e., not adding support for a new
target), you don't need to use this directly. In fact, even if you're
developing for a new target, we may already have a cross-compiler available.

This project's purpose is to contain the information for hex.pm so that Nerves
cross-compilers can be referenced in `mix`. See
[nerves-toolchain](https://github.com/nerves-project/nerves-toolchain) for
the scripts used to generate the actual cross-compiler.

This toolchain is used by the `ev3` target. It is useful for ARM7 processors
that lack hardware floating point.

