use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

app = :nerves_toolchain_armv5tejl_unknown_linux_musleabi

config app, :nerves_env,
  type: :toolchain,
  version: version,
  platform: Nerves.Toolchain.CTNG,
  target_tuple: :armv5tejl_unknown_linux_musleabi,
  artifact_url: [
    "https://github.com/nerves-project/toolchains/releases/download/v#{version}/#{app}-#{version}.#{Nerves.Env.host_platform}-#{Nerves.Env.host_arch}.tar.xz"
  ]
