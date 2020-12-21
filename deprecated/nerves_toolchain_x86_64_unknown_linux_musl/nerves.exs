use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

app = :nerves_toolchain_x86_64_nerves_linux_musl

config app, :nerves_env,
  type: :toolchain,
  version: version,
  compiler: :nerves_package,
  platform: Nerves.Toolchain.CTNG,
  target_tuple: :x86_64_nerves_linux_musl,
  artifact_url: [
    "https://github.com/nerves-project/toolchains/releases/download/v#{version}/#{app}-#{version}.#{Nerves.Env.host_platform}-#{Nerves.Env.host_arch}.tar.xz"
  ],
  checksum: [
    "defconfig",
    "VERSION"
  ]
