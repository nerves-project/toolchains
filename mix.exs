defmodule NervesToolchainMipselUnknownLinuxMusl.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_toolchain_mipsel_unknown_linux_musl,
     version: "0.6.3",
     elixir: "~> 1.2",
     compilers: Mix.compilers ++ [:nerves_toolchain],
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    [env: [
      target_tuple: "mipsel-unknown-linux-musl"
    ]]
  end

  defp deps do
    [{:nerves_toolchain, "~> 0.6.2"}]
  end

  defp description do
    """
    Nerves Toolchain - mipsel-unknown-linux-musl
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Justin Schneck"],
     files: ["lib", "src", "README.md", "LICENSE", "nerves.exs", "mix.exs"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/nerves_toolchain_mipsel_unknown_linux_musl"}]
  end
end
