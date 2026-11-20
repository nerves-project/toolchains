<!--
SPDX-FileCopyrightText: 2026 Frank Hunleth
SPDX-License-Identifier: CC-BY-4.0
-->

# Nerves toolchain builder

Native crosstool-NG recipes for Linux cross-compilers that run on Linux x86_64,
Linux arm64, and macOS 15 or later (x86_64 and arm64). Windows hosts are future work.
The output uses the existing Buildroot-compatible toolchain layout: a single
top-level directory containing `bin/<target>-gcc`, companion tools, and a sysroot.

This directory is self-contained and can become a repository root without
changing its commands. It has no Nerves or Mix package dependencies. Bash and awk
provide build and archive helpers, and Python provides tests. Consumers need none of these
helpers.

## Prerequisites

Install Git and Make plus the platform dependencies below. Python 3 is used by
the test suite and build tools; Erlang and Elixir are not required.

On Debian/Ubuntu:

```sh
sudo apt install build-essential bison flex gperf libncurses-dev texinfo help2man \
  libssl-dev gawk libtool-bin automake autoconf lzip unzip python3 wget curl \
  ca-certificates xz-utils zstd openssl
```

On macOS, use Homebrew:

```sh
brew install python3 gawk binutils xz zstd wget automake gnu-tar help2man \
  bash make ncurses libtool autoconf gnu-sed gcc@16 bison m4 lzip grep coreutils texinfo
export PATH="$(brew --prefix gcc@16)/bin:$PATH"
```

Builds need a case-sensitive filesystem on macOS; `build.sh` creates a disk image.
The packaged headers retain the existing workaround that removes case-conflicting
netfilter headers so that toolchains can be extracted on case-insensitive hosts.

## Building

Run these commands from this directory, whether it is nested or a repository root:

```sh
make list
bash build.sh armv7-nerves-linux-gnueabihf--gcc15
```

Builds resolve the config with the pinned, locally patched crosstool-NG and
reject changes to explicit target settings, even when `savedefconfig` omits
them as defaults. `make ctng` builds and installs crosstool-NG under `o/ct-ng/`;
`build.sh` runs this automatically. Make rebuilds it when the Makefile, patch
script, or patches change. Build temporary files stay under `o/tmp/`.
Downloaded sources are the sole exception to keeping build files under `o/`:
they are cached in `~/.nerves/dl/`.

The argument to `build.sh` is a filename from `configs/` without `.defconfig`.
Work goes in `o/<config>`; release pairs go in `o/artifacts/`. Optional second
and third arguments override the work and output directories. After compilation,
packaging derives its release filename from the installed compiler's target,
`ct-ng.config`, the builder's `VERSION`, and the host argument. Existing archives
or checksums are never replaced. Builds skip an existing archive/checksum pair for
the same target, GCC track, host, and release after verifying its checksum.
On macOS, the build drive is unmounted
and its backing `.dmg` removed on exit, including failure, unless `DEBUG` is set.

`bash build_all.sh` builds all toolchains on this host. It does not publish
anything. Builds are expensive; build one when testing.

### Building in Tart

On an Apple Silicon Mac with [Tart](https://tart.run/quick-start/) and GNU
coreutils installed:

```sh
bash build_with_tart.sh macos armv7-nerves-linux-gnueabihf--gcc16
bash build_with_tart.sh linux armv7-nerves-linux-gnueabihf--gcc16
```

`macos` selects `ghcr.io/cirruslabs/macos-sequoia-base:latest`; `linux` selects
`ghcr.io/cirruslabs/ubuntu:22.04`. The image mapping is at the top of
`build_with_tart.sh`. The wrapper installs build prerequisites automatically, copies
the current source (including uncommitted changes) into the guest's native
filesystem, and runs `build.sh`. Builds run as the image's `admin` user.

The guest uses 4 CPUs, 8 GiB RAM and a 100 GB virtual disk. It is stopped and
deleted on exit; prerequisites and guest-local build/source caches are not
retained. VM image downloads share the smoke-test cache under
`o/tart-tests/tart/`. Build logs, the source snapshot and incoming artifacts
remain under `o/tart-builds/run-*/`.

Successful archive/checksum pairs are verified and published to the host's
`o/artifacts/` without replacing existing files. As with `build.sh`, an existing
matching pair is verified and skipped; move it aside or change the release
version to rebuild it. macOS guests produce `darwin_arm` artifacts; Linux
guests produce `linux_aarch64` artifacts.

Use Sequoia with its older SDK to build macOS distributions for Sequoia and
newer hosts, then run `scripts/test-tart.sh` to check compatibility.

### Building in Docker

With Docker and GNU coreutils installed:

```sh
bash build_with_docker.sh armv7-nerves-linux-gnueabihf--gcc16
```

This builds only `linux_x86_64` toolchains. The Ubuntu 22.04 image and local
builder image tag are listed at the top of `build_with_docker.sh`. Docker
installs and caches the build prerequisites in that image; Erlang and Elixir
are not required.

The wrapper snapshots the current build inputs, mounts them read-only, and
runs `build.sh` as a non-root `builder` user on the container's native
filesystem. Successful archive/checksum pairs are verified and published to
`o/artifacts/` without overwriting existing files. Existing matching pairs
are verified and skipped, just like native and Tart builds.

Build logs, source snapshots and incoming artifacts remain under
`o/docker-builds/run-*/`. The build container is removed on exit, including
failure; its build files and source-download cache are not retained. Docker
retains the cached builder image.

The wrapper requests `linux/amd64`, so native x86_64 Linux is recommended.
Other Docker hosts require working amd64 emulation, which can make compiler
builds significantly slower. Containers use the Docker host's kernel.

Flat configs are named `<target>--<track>.defconfig`. The initial `gcc15` track
uses GCC 15.3.0 and Linux 6.1.175 headers. A newer GCC 16.2 track is planned.
Both tracks should receive current stable libc releases rather than freezing
libc with the compiler: currently glibc 2.43 or musl 1.2.6. glibc's minimum
runtime kernel is explicitly 6.1.0, independent of the headers' patch level.

Keep both the Kconfig selector and resolved version in each config, including
defaults. Pin crosstool-NG with `CTNG_TAG` in the Makefile. Host fragments live in
`defaults/` and must not select target component versions.

To edit a config interactively:

```sh
make ctng
ctng="$PWD/o/ct-ng/bin/ct-ng"
cd o/armv7-nerves-linux-gnueabihf--gcc15/build
"$ctng" menuconfig
"$ctng" savedefconfig
```

Merge the relevant changes back into `configs/`, retaining explicit versions.

## Releases and downloads

`VERSION` is the published recipe's calendar version, `YYYY.MM.N`: year, month,
and release number within that month. For example, `2026.11.1` maps to the
immutable source tag `v2026.11.1`. It is independent of GCC and integration
package versions. Build-input changes and replacement distributions require a
new release, even if the visible component versions stay the same.

Archive names are:

```text
<target>--gcc-<version>-<libc>-<version>-linux-<headers>--<release>--<host>.tar.xz
```

For example:

```text
armv7-nerves-linux-gnueabihf--gcc-15.3.0-glibc-2.43-linux-6.1.175--2026.11.1--linux_x86_64.tar.xz
```

Each archive is paired with `<archive>.sha256`. This is a standard SHA256 checksum
line containing the compressed archive's digest and basename, compatible with
`sha256sum -c`. Published checksum files are the trust
source for now; signatures are not implemented.

The default public download directory is:

```text
https://dl.nerves-project.org/toolchains/
```

Print the canonical archive filename for an installed toolchain:

```sh
bash scripts/archive.sh --name path/to/installed/toolchain linux_x86_64
```

Component versions and build settings are recorded in `ct-ng.config`.
The target is the prefix of `bin/*-gcc`, and the recipe release comes from the
builder's `VERSION`. The host platform is encoded in the archive filename;
there is no separate metadata file or archive-inspection command.

The archive retains a single top-level directory named after the installed
target tuple, independent of component and release versions. To repackage a
completed installation without rebuilding:

```sh
bash scripts/package.sh path/to/installed/toolchain o/artifacts linux_x86_64
```

The installation must contain `ct-ng.config`. Repackaging uses the current
builder's `VERSION`, not the original installation's release.
The host argument is one of `linux_x86_64`, `linux_aarch64`, `darwin_x86_64`,
or `darwin_arm` and is used unchanged in the archive filename. The Linux host
label does not imply a glibc runtime requirement.

Consumers can derive a checksum URL by appending `.sha256` to the archive URL.
They must verify it before extraction.

CI builds Linux x86_64, Linux arm64, and macOS arm64 and releases after those
builds and tests finish. macOS x86_64 remains supported via manual native builds.
Late host builds use the **same source tag**, versions and patches, and add their
own archive/checksum pairs without replacing earlier hosts.

## Publishing

Configure AWS credentials outside the builder. With OpenSSL and a recent AWS CLI
supporting conditional `s3api put-object --if-none-match`, publish to the
bucket/prefix that backs the public URL:

```sh
bash scripts/publish.sh s3://YOUR_BUCKET/toolchains/ o/artifacts
```

The script verifies all pairs first, refuses object replacement using conditional
uploads, and uploads each archive before its checksum. Treat the checksum as the
publication-complete marker. S3 does not atomically publish two objects. Retrying
is safe: existing objects are skipped only when S3's stored SHA256 checksum
matches the local file. This also lets a retry complete an interrupted pair.
Existing objects without a matching server checksum are rejected, not replaced.

GitHub Actions publishing is optional. Configure repository variables
`TOOLCHAIN_S3_DESTINATION`, `TOOLCHAIN_AWS_ROLE_ARN`, and `TOOLCHAIN_AWS_REGION`,
with an AWS OIDC role authorized for that destination. Tagged builds publish
only after validation succeeds. Without a destination, CI only uploads its
GitHub Actions artifacts. The public URL is not assumed to be the bucket name.
The role needs object uploads and reads for checksum-verified retries; object
deletion is not required.

## Validation and reproducibility

```sh
make check
bash scripts/smoketest.sh path/to/toolchain.tar.xz "$PWD/target-smoke.elf"
```

`test/` contains Python unit tests. Toolchain validation scripts and their shared
C++ fixture live under `scripts/`, including `scripts/toolchain-guest.sh` shared
by the Tart and Docker runners.

`make check` runs packaging, checksum and publishing tests and
shell syntax checks without building a compiler. The smoke test checks the
published digest, extracts to a new location, and compiles the C++ fixture.
CI compares its target ELF output byte-for-byte across the three CI build hosts
and checks relocation on the supported test runners.

Reproducibility means equivalent target output across rebuilds and supported
hosts, not identical compiler binaries or compressed archives. The smoke fixture
uses controlled flags and excludes debug information and build IDs; it is a
regression check, not proof that all programs produce identical output. Preserve
reference outputs when qualifying future rebuilds, using the same source, flags,
paths and environment. A replacement archive's digest may differ and must have
a new distribution release.

### Tart compatibility tests

On an Apple Silicon Mac with [Tart](https://tart.run/quick-start/) and GNU
coreutils installed:

```sh
bash scripts/test-tart.sh o/artifacts/<archive>.tar.xz
bash scripts/test-tart.sh all
bash scripts/test-tart.sh all /path/to/archives
```

The script verifies archive/checksum pairs before starting VMs. It tests
`darwin_arm` archives on macOS Sequoia and Golden Gate. It tests
`linux_aarch64` archives on Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, and Rocky Linux 9
(RHEL-compatible). Ubuntu 26.04 and Alpine are not yet
included. A single archive is tested only on its corresponding host OS;
`all` selects compatible archives and explicitly reports skipped architectures
and host OSes with no archives. Use Docker below for x86_64 Linux archives.

Each guest extracts the archives to fresh locations, compiles and links C, C++
and LTO examples, checks binutils, and tests Fortran and GDB when configured.
Target executables are not run. The tests verify the guest OS version and run
with a system-only PATH and no inherited environment.

VMs run sequentially and are stopped and deleted on exit, including on failure.
Tart images are large; allow tens of gigabytes per image for the initial download.
The image cache stays under `o/tart-tests/tart/`, and each run's logs and
`results.tsv` stay under `o/tart-tests/run-*/`. Archive and test directories are
shared read-only with guests. No guest packages are installed by the script.
The published base images include Homebrew on macOS, so these checks complement,
rather than replace, inspection for accidental external library dependencies.
Image tags track updates and do not guarantee testing the initial macOS 15.0
patch release or older Ubuntu kernels.

### Docker compatibility tests

On x86_64 Linux with Docker and GNU coreutils installed:

```sh
bash scripts/test-container.sh o/artifacts/<archive>--linux_x86_64.tar.xz
bash scripts/test-container.sh all
bash scripts/test-container.sh all /path/to/archives
```

The runner verifies strict archive/checksum pairs before using Docker and tests
only `linux_x86_64` archives. Ubuntu 22.04, Ubuntu 24.04, and Alpine 3.24 images
are listed at the top of the script; `CONTAINER_IMAGES` can override the
whitespace-separated list of full image names.

Docker builds and caches minimal test images with `xz` for archive extraction.
No host compiler, glibc compatibility package, or other toolchain dependencies
are installed. Each archive is extracted in a fresh container and runs the same
C, C++, LTO, binutils, optional Fortran and GDB checks as Tart. The checks verify
the distribution version and x86_64 architecture. Target executables are not run.

Archives and tests are mounted read-only. Test containers have no network access,
run as the invoking user's UID/GID, and are removed after testing or interruption.
Logs and `results.tsv` stay under `o/container-tests/run-*/`; image layers remain
in Docker's cache. Tests continue after individual archive or image failures
and return a nonzero exit status if anything fails.

Containers share the Docker host's kernel: this tests distro userspaces, not
older kernels. The runner requests `linux/amd64`; an ARM Docker daemon can run
it if amd64 emulation is already configured, but that is not native x86_64
validation. No macOS-specific setup is provided.

### Build records

Archives retain `ct-ng.config`, `ct-ng.defconfig`, and `share/toolchain-builder/`
with the recipe files. Keep upstream source archives
and their verification data available for rebuilding and corresponding-source
distribution; a recipe snapshot alone does not replace those sources.

The `.github/workflows/` files are ready to move with this directory. While
nested, copies at the parent repository's workflow root select this directory;
GitHub only discovers workflows at a repository's root `.github/workflows/`.
