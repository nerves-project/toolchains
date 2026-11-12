# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

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
    Path.wildcard(Path.join(@root, "configs/nerves_toolchain_*/defconfig"))
    |> Enum.map(&(Path.dirname(&1) |> Path.basename()))
    |> Enum.sort()
  end

  def metadata(app) do
    unless app in targets(), do: raise("Unknown toolchain: #{app}")
    version = File.read!(Path.join(@root, "VERSION")) |> String.trim()
    target = String.replace_prefix(app, "nerves_toolchain_", "") |> String.replace("_", "-")

    files =
      [
        "build.sh",
        "config.exs",
        "VERSION",
        "defaults/**",
        "patches/**",
        "scripts/**",
        "configs/#{app}/*"
      ]
      |> Enum.flat_map(&Path.wildcard(Path.join(@root, &1)))
      |> Enum.filter(&File.regular?/1)

    fingerprint = checksum(files)
    name = "#{target}--#{version}-#{fingerprint}"
    site = "https://github.com/nerves-project/toolchains/releases/download/v#{version}"

    %{
      name: name,
      version: version,
      archives:
        Map.new(@hosts, fn {_legacy, host} -> {host, "#{site}/#{name}--#{host}.tar.xz"} end)
    }
  end

  def contents(app) do
    metadata = metadata(app)

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

  def archive_names(app, host) do
    metadata = metadata(app)
    canonical_host = Map.fetch!(@hosts, host)
    fingerprint = :crypto.hash(:sha256, contents(app)) |> then(&:crypto.hash(:sha256, &1))
    fingerprint = Base.encode16(fingerprint) |> String.slice(0, 7)

    {
      "#{metadata.name}--#{canonical_host}.tar.xz",
      "#{app}-#{host}-#{metadata.version}-#{fingerprint}.tar.xz"
    }
  end

  defp checksum(files) do
    files
    |> Enum.map(&:crypto.hash(:sha256, File.read!(&1)))
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16()
    |> String.slice(0, 7)
  end
end
