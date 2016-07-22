use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_x86_64_unknown_linux_musl, :nerves_env,
  type: :toolchain,
  version: version,
  target_tuple: :x86_64_unknown_linux_musl
  build_platform: Nerves.Toolchain.CTNG
  build_config: [
    defconfig: [
      darwin: "darwin_defconfig",
      linux: "linux_defconfig"
    ]
  ]
