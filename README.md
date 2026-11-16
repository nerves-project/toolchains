<!--
SPDX-FileCopyrightText: 2026 Frank Hunleth
SPDX-License-Identifier: CC-BY-4.0
-->

# Nerves Toolchains

This repository contains native cross-toolchain recipes and their Nerves
integration packages:

* [`toolchain_builder/`](toolchain_builder/README.md) is a self-contained native
  crosstool-NG builder. Its build commands, configs, patches, tests, release
  tooling and CI definitions can move to a separate repository.
* [`nerves_toolchain_gcc/`](nerves_toolchain_gcc/README.md) integrates arbitrary
  GCC toolchain releases with Nerves 2, without tying Mix dependency versions
  to GCC or libc versions.
* `template/` and `generate_toolchains.exs` maintain the twelve existing
  compatibility packages. Nerves 1 archive aliases remain deferred while the
  builder is revised.

## Native toolchains

See the [builder README](toolchain_builder/README.md) for prerequisites, naming,
configuration, verification and publishing. No Nerves or Mix dependencies are
needed to build compilers.

```sh
make -C toolchain_builder versions
bash toolchain_builder/build.sh armv7-nerves-linux-gnueabihf--gcc15
make -C toolchain_builder check
```

The existing `build_one.sh` and `build_release.sh` entrypoints delegate to the
builder. Work and output now stay inside `toolchain_builder/o/`.

Native releases use independent calendar recipe versions and `.tar.zst` archives,
each paired with a `.sha256` file. Downloads default to
`https://dl.nerves-project.org/toolchains/`; `TOOLCHAIN_BASE_URL` changes generated
URLs without changing filenames.

## Integration packages

```sh
make                 # resolve versions and generate compatibility packages
make generate        # generate using existing component metadata
make check           # compile, document and Hex-package all thirteen packages
make test            # builder and generic GCC integration tests; no compiler build
mix format --check-formatted
```

The compatibility package version in `template/VERSION` is independent of the
builder's calendar version. Do not edit the ignored generated package directories.
Native archive aliases and Nerves 1 publishing integration are not implemented
in the revised release pipeline yet.

New Nerves 2 systems should select immutable native archive URLs through
`NervesToolchainGCC`. Its [README](nerves_toolchain_gcc/README.md) describes the
system-local configuration. No compatibility package dependency is required.
