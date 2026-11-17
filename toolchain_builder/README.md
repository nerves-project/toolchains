<!--
SPDX-FileCopyrightText: 2026 Frank Hunleth
SPDX-License-Identifier: CC-BY-4.0
-->

# Nerves toolchain builder

Native crosstool-NG recipes for Linux cross-compilers that run on Linux x86_64,
Linux arm64, macOS x86_64, and macOS arm64. Windows hosts are future work.
The output uses the existing Buildroot-compatible toolchain layout: a single
top-level directory containing `bin/<target>-gcc`, companion tools, and a sysroot.

This directory is self-contained and can become a repository root without
changing its commands. It has no Nerves or Mix package dependencies. Elixir
scripts provide configuration/metadata helpers, Python provides release tooling
and tests, and Bash drives native builds. Consumers need none of these helpers.

## Prerequisites

Install Elixir 1.17 or newer with its Erlang runtime, Python 3, Git, and Make.
The `mix` executable is only used to format Elixir scripts; there is no Mix project
and no Hex dependencies to install.

On Debian/Ubuntu:

```sh
sudo apt install build-essential bison flex gperf libncurses-dev texinfo help2man \
  libssl-dev gawk libtool-bin automake autoconf lzip unzip python3 wget curl \
  ca-certificates xz-utils zstd
```

On macOS, use Homebrew:

```sh
brew install elixir python3 gawk binutils xz zstd wget automake gnu-tar help2man \
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
them as defaults. The cached crosstool-NG identity includes its commit and
local preparation/patch inputs. Caches remain under `~/.nerves/ct-ng/` and
`~/.nerves/dl/`.

The argument to `build.sh` is a filename from `configs/` without `.defconfig`.
Work goes in `o/<config>`; release pairs go in `o/artifacts/`. Optional second
and third arguments override the work and output directories. After compilation,
packaging records the resolved component versions, creates an archive, and
derives its release filename from the archived metadata. Existing archives or
checksums are never replaced; collisions are detected at packaging time.
Ctrl+C terminates the build's descendants.

`bash build_all.sh` builds all toolchains on this host. It does not publish
anything. Builds are expensive; build one when testing.

Flat configs are named `<target>--<track>.defconfig`. The initial `gcc15` track
uses GCC 15.3.0 and Linux 6.1.175 headers. A newer GCC 16.2 track is planned.
Both tracks should receive current stable libc releases rather than freezing
libc with the compiler: currently glibc 2.43 or musl 1.2.6. glibc's minimum
runtime kernel is explicitly 6.1.0, independent of the headers' patch level.

Keep both the Kconfig selector and resolved version in each config, including
defaults. Pin crosstool-NG separately in `config.exs`. Host fragments live in
`defaults/` and must not select target component versions.

To edit a config interactively:

```sh
ctng="$(elixir scripts/ctng.exs)"
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
armv7-nerves-linux-gnueabihf--gcc-15.3.0-glibc-2.43-linux-6.1.175--2026.11.1--x86_64-linux-gnu.tar.xz
```

Each archive is paired with `<archive>.sha256`. This is a standard SHA256 checksum
line containing the compressed archive's digest and basename, compatible with
`sha256sum -c` or macOS `shasum -a 256 -c`. Published checksum files are the trust
source for now; signatures are not implemented.

The default public download directory is:

```text
https://dl.nerves-project.org/toolchains/
```

Inspect a completed archive or print its canonical filename:

```sh
elixir scripts/archive.exs path/to/toolchain.tar.xz
elixir scripts/archive.exs --name path/to/toolchain.tar.xz
```

The report is sorted `key=value` text containing the target, host, recipe release,
libc, and resolved component versions. Inspection streams the metadata into
memory using GNU tar and xz, without extracting files to disk or running the
compiler. Metadata is the first archive member, so inspecting it does not
require decompressing the compiler payload. Neither command needs the source
configs, and renaming an archive does not affect its reported identity.

The archive retains a single top-level directory named after the installed
target tuple, independent of component and release versions. To repackage a
completed installation without rebuilding:

```sh
bash scripts/package.sh path/to/installed/toolchain o/artifacts linux_x86_64
```

The installation must contain `ct-ng.config` and `toolchain-builder.version`.
The host argument is one of `linux_x86_64`, `linux_aarch64`, `darwin_x86_64`,
or `darwin_arm`.

Consumers can derive a checksum URL by appending `.sha256` to the archive URL.
They must verify it before extraction; metadata inspection does not verify the
archive's checksum.

CI builds Linux x86_64, Linux arm64, and macOS arm64 and releases after those
builds and tests finish. macOS x86_64 remains supported via manual native builds.
Late host builds use the **same source tag**, versions and patches, and add their
own archive/checksum pairs without replacing earlier hosts.

## Publishing

Configure AWS credentials outside the builder. With a recent AWS CLI supporting
conditional `s3api put-object --if-none-match`, publish to the bucket/prefix that
backs the public URL:

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
bash test/smoketest.sh path/to/toolchain.tar.xz "$PWD/target-smoke.elf"
```

`make check` runs cancellation, packaging, checksum and publishing tests and
format/syntax checks without building a compiler. The smoke test checks the
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

Archives retain `ct-ng.config`, `ct-ng.defconfig`, `toolchain-builder.version`,
`toolchain-builder.metadata`, and `share/toolchain-builder/` with the recipe
files and a JSON build manifest. The manifest records the crosstool-NG commit,
recipe digests, host compiler,
platform, macOS SDK, and available Git provenance. Keep upstream source archives
and their verification data available for rebuilding and corresponding-source
distribution; a recipe snapshot alone does not replace those sources.

The `.github/workflows/` files are ready to move with this directory. While
nested, copies at the parent repository's workflow root select this directory;
GitHub only discovers workflows at a repository's root `.github/workflows/`.
