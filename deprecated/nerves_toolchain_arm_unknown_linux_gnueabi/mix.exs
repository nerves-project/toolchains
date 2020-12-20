defmodule NervesToolchainArmNervesLinuxGnueabi.MixProject do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.strip()

  def project do
    [
      app: :nerves_toolchain_arm_nerves_linux_gnueabi,
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
        target_tuple: :arm_nerves_linux_gnueabi
      ]
    ]
  end

  defp deps do
    [{:nerves, "~> 0.4.0"}, {:nerves_toolchain_ctng, "~> 0.8.0"}]
  end

  defp description do
    """
    Nerves Toolchain - arm-nerves-linux-gnueabi
    """
  end

  defp package do
    [
      files: [
        "lib",
        "defconfig",
        "mingw32_x86_64_defconfig",
        "README.md",
        "LICENSE",
        "nerves.exs",
        "mix.exs",
        "VERSION"
      ],
      licenses: ["Apache 2.0"],
      links: %{
        "Github" =>
          "https://github.com/nerves-project/toolchains/nerves_toolchain_arm_nerves_linux_gnueabi"
      }
    ]
  end
end
