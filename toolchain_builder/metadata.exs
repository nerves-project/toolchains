# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("defconfig.exs", __DIR__)

defmodule ToolchainMetadata do
  @root __DIR__
  @hosts %{
    "linux_x86_64" => "x86_64-linux-gnu",
    "linux_aarch64" => "aarch64-linux-gnu",
    "darwin_x86_64" => "x86_64-apple-darwin",
    "darwin_arm" => "aarch64-apple-darwin"
  }

  def hosts, do: @hosts

  def targets do
    Path.wildcard(Path.join(@root, "configs/*.defconfig"))
    |> Enum.map(&Path.basename(&1, ".defconfig"))
    |> Enum.sort()
  end

  def config_path(toolchain), do: Path.join(@root, "configs/#{toolchain}.defconfig")

  def metadata(toolchain) do
    unless toolchain in targets(), do: raise("Unknown toolchain: #{toolchain}")
    version = File.read!(Path.join(@root, "VERSION")) |> String.trim()
    target = toolchain |> String.split("--", parts: 2) |> hd()
    config = ToolchainDefconfig.read!(config_path(toolchain))
    gcc = component_version!(config, "GCC")
    linux = component_version!(config, "LINUX")
    libc = if Map.get(config, "CT_LIBC_MUSL") == "y", do: "MUSL", else: "GLIBC"
    libc_version = component_version!(config, libc)

    name =
      "#{target}--gcc-#{gcc}-#{String.downcase(libc)}-#{libc_version}-linux-#{linux}--#{version}"

    site = "https://github.com/nerves-project/toolchains/releases/download/v#{version}"

    %{
      name: name,
      version: version,
      archives:
        Map.new(@hosts, fn {_legacy, host} -> {host, "#{site}/#{name}--#{host}.tar.xz"} end)
    }
  end

  def contents(toolchain) do
    metadata = metadata(toolchain)

    archives =
      metadata.archives
      |> Enum.sort()
      |> Enum.map_join(",\n", fn {host, url} -> "    #{inspect(host)} => #{inspect(url)}" end)

    # This file's bytes determine legacy filenames on builders using different Elixir versions.
    """
    %{
      name: #{inspect(metadata.name)},
      version: #{inspect(metadata.version)},
      archives: %{
    #{archives}
      }
    }
    """
  end

  def archive_name(toolchain, host) do
    metadata = metadata(toolchain)
    canonical_host = Map.fetch!(@hosts, host)
    "#{metadata.name}--#{canonical_host}.tar.xz"
  end

  defp component_version!(config, component) do
    config
    |> Map.fetch!("CT_#{component}_VERSION")
    |> String.trim("\"")
  end
end
