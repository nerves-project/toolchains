use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_armv6_rpi_linux_gnueabi, :nerves_env,
  type: :toolchain,
  version: version,
  target_tuple: :armv6_rpi_linux_musl,
  platform: Nerves.Toolchain.CTNG
