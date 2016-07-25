use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_ctng, :nerves_env,
  type: :toolchain_platform,
  version: version
