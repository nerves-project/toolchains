use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_i586_unknown_linux_gnu, :nerves_env,
  type: :toolchain,
  version: version,
  target_tuple: :i586_unknown_linux_gnu,
  platform: Nerves.Toolchain.CTNG
