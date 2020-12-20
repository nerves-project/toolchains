use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

app = :nerves_toolchain_arm_nerves_linux_gnueabi

config app, :nerves_env,
  type: :toolchain,
  version: version,
  compiler: :nerves_package,
  platform: Nerves.Toolchain.CTNG,
  target_tuple: :arm_nerves_linux_gnueabi,
  artifact_url: [
    "https://github.com/nerves-project/toolchains/releases/download/v#{version}/#{app}-#{version}.#{Nerves.Env.host_platform}-#{Nerves.Env.host_arch}.tar.xz"
  ],
  checksum: [
    "defconfig",
    "VERSION"
  ]
