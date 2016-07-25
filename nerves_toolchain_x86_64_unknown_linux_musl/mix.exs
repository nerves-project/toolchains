defmodule NervesToolchainX8664UnknownLinuxMusl.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
    |> File.read!
    |> String.strip

  def project do
    [app: :nerves_toolchain_x86_64_unknown_linux_musl,
     version: @version,
     elixir: "~> 1.3",
     description: description,
     package: package,
     aliases: ["deps.precompile": ["nerves.precompile", "deps.precompile"]],
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: []]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:nerves_toolchain_ctng, path: "../nerves_toolchain_ctng"}]
  end

  defp description do
    """
    Nerves Toolchain - x86_64-unknown-linux-musl
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Justin Schneck"],
     files: ["lib", "linux_defconfig", "darwin_defconfig", "README.md", "LICENSE", "nerves.exs", "mix.exs"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/toolchains/x86_64_unknown_linux_musl"}]
  end

end
