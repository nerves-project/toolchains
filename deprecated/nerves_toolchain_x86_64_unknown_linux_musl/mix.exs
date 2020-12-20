defmodule NervesToolchainX8664NervesLinuxMusl.MixProject do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.strip()

  def project do
    [
      app: :nerves_toolchain_x86_64_nerves_linux_musl,
      version: @version,
      elixir: "~> 1.4",
      compilers: Mix.compilers() ++ [:nerves_package],
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      env: [
        target_tuple: :x86_64_nerves_linux_musl
      ]
    ]
  end

  defp deps do
    [{:nerves, "~> 0.4.0"}, {:nerves_toolchain_ctng, "~> 0.8.0"}]
  end

  defp description do
    """
    Nerves Toolchain - x86_64-nerves-linux-musl
    """
  end

  defp package do
    [
      files: ["lib", "defconfig", "README.md", "LICENSE", "nerves.exs", "mix.exs", "VERSION"],
      licenses: ["Apache 2.0"],
      links: %{
        "Github" =>
          "https://github.com/nerves-project/toolchains/nerves_toolchain_x86_64_nerves_linux_musl"
      }
    ]
  end
end
