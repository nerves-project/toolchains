use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_armv5tejl_unknown_linux_musleabi, :nerves_env,
  type: :toolchain,
  version: version,
  target_tuple: "armv5tejl-unknown-linux-musleabi",
  platform: Nerves.Toolchain.CTNG,
  platform_config: [
    defconfig: [
      darwin: "darwin_defconfig",
      linux: "linux_defconfig"
    ]
  ]
