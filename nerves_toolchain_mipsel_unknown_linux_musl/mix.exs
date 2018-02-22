defmodule NervesToolchainMipselUnknownLinuxMusl.Mixfile do
  use Mix.Project

  @app :nerves_toolchain_mipsel_unknown_linux_musl
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.4",
      compilers: [:nerves_package | Mix.compilers()],
      nerves_package: nerves_package(),
      description: description(),
      package: package(),
      deps: deps(),
      aliases: [loadconfig: [&bootstrap/1]]
    ]
  end

  def application do
    []
  end

  defp bootstrap(args) do
    System.put_env("MIX_TARGET", "CC")
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  defp nerves_package do
    [
      type: :toolchain,
      platform: Nerves.Toolchain.CTNG,
      platform_config: [
        defconfig: "defconfig"
      ],
      target_tuple: :mipsel_unknown_linux_musl,
      artifact_sites: [
        {:github_releases, "nerves-project/toolchains"}
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      {:nerves, "~> 1.0-rc", runtime: false},
      {:nerves_toolchain_ctng, "~> 1.4-rc", runtime: false}
    ]
  end

  defp description do
    """
    Nerves Toolchain - mipsel-unknown-linux-musl
    """
  end

  defp package do
    [
      maintainers: ["Frank Hunleth", "Justin Schneck"],
      files: package_files(),
      licenses: ["Apache 2.0"],
      links: %{
        "Github" =>
          "https://github.com/nerves-project/toolchains/#{@app}"
      }
    ]
  end

  defp package_files do
    [
      "defconfig",
      "README.md",
      "LICENSE",
      "mix.exs",
      "VERSION"
    ]
  end
end
