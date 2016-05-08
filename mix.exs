defmodule NervesToolchainArmUnknownLinuxGnueabi.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_toolchain_arm_unknown_linux_gnueabi,
     version: "0.6.1",
     elixir: "~> 1.2",
     compilers: Mix.compilers ++ [:nerves_toolchain],
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    [env: [
      target_tuple: "arm-unknown-linux-gnueabi"
    ]]
  end

  defp deps do
    [{:nerves_toolchain, "~> 0.6.1"}]
  end

  defp description do
    """
    Nerves Toolchain - arm-unknown-linux-gnueabi
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/nerves_toolchain_arm_unknown_linux_gnueabi"}]
  end

end
