<!--
SPDX-FileCopyrightText: 2026 Frank Hunleth
SPDX-License-Identifier: CC-BY-4.0
-->

# Generic GCC toolchain integration for Nerves 2

This package downloads and activates prebuilt GCC toolchains. It does not build
compilers or depend on any of the twelve legacy toolchain packages. Its version
describes the integration code, not GCC or libc.

## System configuration

Add the same integration dependency to each Nerves 2 system:

```elixir
{:nerves_toolchain_gcc, "~> 0.1", runtime: false}
```

In the system's `:nerves` configuration, register a build action with immutable,
host-specific archive URLs:

```elixir
nerves: [
  # Keep the system's other actions and configuration.
  actions: [
    {NervesToolchainGCC,
     archives: %{
       "x86_64-linux-gnu" => "https://example.com/releases/toolchain-linux-x86_64.tar.xz",
       "aarch64-linux-gnu" => "https://example.com/releases/toolchain-linux-aarch64.tar.xz",
       "aarch64-apple-darwin" => "https://example.com/releases/toolchain-macos-aarch64.tar.xz"
     }}
  ]
]
```

For Nerves-built toolchains, copy the `:archives` map from a generated compatibility
package's `toolchain.exs`. Keep that map in the system's source; do not add a
dependency on the compatibility package to obtain it. Other GCC toolchains,
including Bootlin's Linux-hosted toolchains, can be selected using the same API.
There is no global application configuration or compiler-version constraint.

Configure only the selected system for each Mix target. Different systems can
pin different compiler URLs while sharing this one Mix dependency. Download and
extraction caches are keyed by the archive selection, not the integration package
version. An explicit `MIX_TARGET=host` should normally omit system dependencies.

## Archive layout and activation

Archives may be `.tar.xz`, `.tar.gz`, or `.tar.zst`. They must contain one
top-level directory, removed during extraction, with `bin/<prefix>-gcc` and its
companion GCC tools and sysroot. The compiler must support relocation.

The action discovers the compiler prefix and exports `NERVES_TOOLCHAIN`,
`CROSSCOMPILE`, `REBAR_TARGET_ARCH`, `AR`, `AS`, `CC`, `CXX`, `LD`, and `STRIP`,
and prepends the toolchain's `bin` directory to `PATH`. If an archive provides
multiple prefixes, add `prefix: "arm-example-linux-gnueabihf"` to the action
options. Other system actions still supply the target ABI and SDK environment.

Set `NERVES_TOOLCHAIN` to an extracted directory for local development. No archive
is downloaded in that case. Native macOS archives are selected on macOS; no
Linux container is used to build or activate them.

Archives are checked for corruption. SHA256 manifests and release verification
are deferred; use trusted, immutable URLs in the meantime.
