defmodule NervesToolchainI586UnknownLinuxGnu.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_toolchain_i586_unknown_linux_gnu,
     version: "0.6.0",
     elixir: "~> 1.2",
     compilers: Mix.compilers ++ [:nerves_toolchain],
     description: description,
     package: package,
     deps: deps]
  end

  def application do
   [env: [
     target_tuple: "i586-unknown-linux-gnu"
   ]]
  end

  defp deps do
   [{:nerves_toolchain, "~> 0.6.1"}]
  end

  defp description do
   """
   Nerves Toolchain - i586-unknown-linux-gnu
   """
  end

  defp package do
   [maintainers: ["Frank Hunleth", "Justin Schneck"],
    files: ["lib", "src", "README.md", "LICENSE", "nerves.exs"],
    licenses: ["Apache 2.0"],
    links: %{"Github" => "https://github.com/nerves-project/nerves_toolchain_i586_unknown_linux_gnu"}]
  end
end
