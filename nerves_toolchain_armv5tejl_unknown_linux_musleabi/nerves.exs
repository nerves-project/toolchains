use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_armv5tejl_unknown_linux_musleabi, :nerves_env,
  type: :toolchain,
  version: version,
  target_tuple: :armv5tejl_unknown_linux_musleabi,
  platform: Nerves.Toolchain.CTNG
