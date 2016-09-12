use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_mipsel_unknown_linux_musl, :nerves_env,
  type: :toolchain,
  version: version,
  target_tuple: :mipsel_unknown_linux_musl,
  platform: Nerves.Toolchain.CTNG
