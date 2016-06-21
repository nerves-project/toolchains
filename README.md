# NervesToolchainMipselUnknownLinuxMusl

This is the `mix` package for the Nerves MIPS toolchain using the Musl C
library.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add nerves_toolchain_mipsel_unknown_linux_musl to your list of dependencies in `mix.exs`:

        def deps do
          [{:nerves_toolchain_mipsel_unknown_linux_musl, "~> 0.0.1"}]
        end

  2. Ensure nerves_toolchain_mipsel_unknown_linux_musl is started before your application:

        def application do
          [applications: [:nerves_toolchain_mipsel_unknown_linux_musl]]
        end

