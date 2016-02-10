defmodule NervesToolchainArmUnknownLinuxGnueabihf.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_toolchain_arm_unknown_linux_gnueabihf,
     version: "0.5.0",
     elixir: "~> 1.2",
     compilers: Mix.compilers ++ [:nerves_toolchain],
     deps: deps]
  end

  def application do
    [env: [
      target_tuple: "arm-unknown-linux-gnueabihf"
    ]]
  end

  defp deps do
    [{:nerves_toolchain, path: "../nerves_toolchain"}]
  end
end
