defmodule NervesToolchainArmv6RpiLinuxGnueabi.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
    |> File.read!
    |> String.strip

  def project do
    [app: :nerves_toolchain_armv6_rpi_linux_gnueabi,
     version: @version,
     elixir: "~> 1.2",
     compilers: Mix.compilers ++ [:nerves_toolchain],
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    [env: [
      target_tuple: "armv6-rpi-linux-gnueabi"
    ]]
  end

  defp deps do
    [{:nerves_toolchain, "~> 0.6.1"}]
  end

  defp description do
    """
    Nerves Toolchain - armv6-rpi-linux-gnueabi
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Justin Schneck"],
     files: ["lib", "src", "README.md", "LICENSE", "nerves.exs", "mix.exs"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/nerves_toolchain_armv6_rpi_linux_gnueabi"}]
  end

end
