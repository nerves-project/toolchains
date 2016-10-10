# Release Instructions

Since all toolchains share the same repository, release versions many not contain artifacts for all toolchains.

These steps must be repeated for each toolchain that is part of the overall release.

`<toolchain>` is a placeholder for the name of the toolchain you are building.

**Changing Version**
  - [ ] Check mix deps for version bumps and ensure that they are pushed and pointed to Hex
  (`nerves_toolchain_ctng`/`nerves_toolchain` | `nerves`)
  - [ ] Bump version in related files listed below
  - [ ] Commit changes
  - [ ] Tag repository

**Building Artifacts**

Artifacts need to be produced for all host / target combinations for the toolchains being released.

  - [ ] Linux (On Linux): `nerves_toolchain_ctng/build.sh <toolchain>`
  - [ ] macOS (On macOS): `nerves_toolchain_ctng/build.sh <toolchain>`

Canadian Cross builds

  - [ ] arm

  Download the RaspberryPi cross-toolchain

  ```
  $ git clone git://github.com/raspberrypi/tools.git
  ```

  Build the toolchain

  ```
  $ export HOST_OS=linux
  $ export HOST_ARCH=arm
  $ export PATH=<path to tools>/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin
  $ ./nerves_toolchain_ctng/build.sh <toolchain>
  ```

  - [ ] Windows

  Install mingw

  ```
  $ sudo apt-get install g++-mingw-w64-x86-64
  ```

  Build the toolchain

  ```
  $ export HOST_OS=mingw32
  $ ./nerves_toolchain_ctng/build.sh <toolchain>
  ```

**Publishing the Release**

  - [ ] Push changes
  - [ ] Start a new Github release with tag
  - [ ] Upload toolchains to Github release
  - [ ] Publish release
  - [ ] Test pulling the artifact `mix do deps.get, compile`
  - [ ] Push to hex `mix hex.publish package`
  - [ ] Start `-dev` version

## Files with Version

  * `CHANGELOG.md`
  * `<toolchain>/mix.exs`
  * `<toolchain>/VERSION`
