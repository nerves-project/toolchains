# Toolchain Releases

## v0.9.0

  * New features
    * Bump gcc version from 4.9 to 5.3 - THIS BREAKS COMPILATION OF OLD LINUX
      KERNELS! If you have no choice but to use an old Linux kernel, please
      do not upgrade to this toolchain.
    * Added x86_64 toolchain that's built against glibc

## v0.8.0

  * New features
    * Refactored defconfigs so that platform-independent and platform-dependent
      parts are stored separately. This majorly simplifies maintenance.
    * Added support for the `:nerves_package` compiler

## v0.7.2

### armv6_rpi_linux_gnueabi

  * Bug Fixes
    * [darwin] fixed defconfig to use 3.12 linux kernel headers

## v0.7.1

  * New features
    * First release using combined toolchain repository
