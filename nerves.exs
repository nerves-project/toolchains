use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_toolchain_arm_unknown_linux_gnueabi, :nerves_env,
  type: :toolchain,
  target_tuple: "armv6-rpi-linux-gnueabi",
  mirrors: [
    "https://github.com/nerves-project/nerves_toolchain_armv6-rpi-linux-gnueabi/releases/download/v#{version}/nerves_toolchain_armv6-rpi-linux-gnueabi-v#{version}.tar.xz"],
  build_platform: Nerves.Toolchain.Platforms.CTNG
