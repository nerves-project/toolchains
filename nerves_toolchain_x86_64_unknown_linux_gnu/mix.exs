defmodule NervesToolchainX8664UnknownLinuxGnu.Mixfile do
  use Mix.Project

  @app :nerves_toolchain_x86_64_unknown_linux_gnu
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
      aliases: ["deps.precompile": ["nerves.env", "deps.precompile"]]
    ]
  end

  def nerves_package do
    [
      type: :toolchain,
      platform: Nerves.Toolchain.CTNG,
      platform_config: [
        defconfig: "defconfig"
      ],
      target_tuple: :x86_64_unknown_linux_gnu,
      artifact_sites: [
        {:github_releases, "nerves-project/toolchains"}
      ],
      checksum: package_files()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:nerves, "~> 0.9", runtime: false},
      #{:nerves_toolchain_ctng, "~> 1.3", runtime: false}
      {:nerves_toolchain_ctng, path: "../nerves_toolchain_ctng", runtime: false}
    ]
  end

  defp description do
    """
    Nerves Toolchain - x86_64-unknown-linux-gnu
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
