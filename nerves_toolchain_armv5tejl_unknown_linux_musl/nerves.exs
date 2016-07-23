use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_armv5tejl_unknown_linux_musl, :nerves_env,
  type: :toolchain,
  version: version,
  target_tuple: :armv5tejl_unknown_linux_musl
  build_platform: Nerves.Toolchain.CTNG
  build_config: [
    defconfig: [
      darwin: "darwin_defconfig",
      linux: "linux_defconfig"
    ]
  ]
