defmodule NervesToolchainArmUnknownLinuxGnueabihf.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_toolchain_arm_unknown_linux_gnueabihf,
     version: "0.6.0",
     elixir: "~> 1.2",
     compilers: Mix.compilers ++ [:nerves_toolchain],
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    [env: [
      target_tuple: "arm-unknown-linux-gnueabihf"
    ]]
  end

  defp deps do
    [{:nerves_toolchain, "~> 0.6.1"}]
  end

  defp description do
    """
    Nerves Toolchain - arm-unknown-linux-gnueabihf
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/nerves_toolchain_arm_unknown_linux_gnueabihf"}]
  end
end
