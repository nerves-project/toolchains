file = "../nerves_toolchain_helpers.exs"
file = if File.exists?(file), do: file, else: Path.basename(file)
Code.require_file(file)

defmodule NervesToolchainArmv6RpiLinuxGnueabi.Mixfile do
  use Mix.Project

  @app     :nerves_toolchain_armv6_rpi_linux_gnueabi
  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.trim

  def project do
    [app: @app,
     version: @version,
     elixir: "~> 1.4",
     compilers: [:nerves_package],
     nerves_package: nerves_package(),
     description: description(),
     package: package(),
     deps: deps(),
     aliases: ["deps.precompile": ["nerves.env", "copy.toolchain.helpers", "deps.precompile"]]]
  end

  def nerves_package do
   [type: :toolchain,
    platform: Nerves.Toolchain.CTNG,
    target_tuple: :armv6_rpi_linux_gnueabi,
    artifact_url: [
      "https://github.com/nerves-project/toolchains/releases/download/v#{@version}/#{@app}-#{@version}.#{Nerves.Toolchain.host_platform()}-#{Nerves.Toolchain.host_arch()}.tar.xz"
    ],
    checksum: [
      "defconfig"
    ]]
  end

  def application do
    []
  end

  defp deps do
    [
      {:nerves, "~> 0.8"},
      {:nerves_toolchain_ctng, "~> 1.2"}
    ]
  end

  defp description do
    """
    Nerves Toolchain - armv6-rpi-linux-gnueabi
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Justin Schneck"],
     files: ["defconfig", "README.md", "LICENSE", "mix.exs", "nerves_toolchain_helpers.exs", "VERSION"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/toolchains/nerves_toolchain_armv6_rpi_linux_gnueabi"}]
  end
end
