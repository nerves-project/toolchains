This is an umbrella project for all of the Nerves toolchains.

See the subdirectories for the actual toolchains and the nerves_toolchain_ctng
directory for the build scripts.

## Canadian cross builds for Raspberry Pi

It's possible to build a toolchain that runs on the Raspberry Pi on x86 Linux.
This is called a Canadian-cross. To do so, first clone the Raspberry Pi
cross-toolchain:

    $ git clone git://github.com/raspberrypi/tools.git

Then run a toolchain build as follows:

    $ export HOST_OS=linux
    $ export HOST_ARCH=arm
    $ export PATH=<path to tools>/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin
    $ ./nerves_toolchain_ctng/build.sh <toolchain>

