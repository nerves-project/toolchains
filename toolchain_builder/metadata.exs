# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("defconfig.exs", __DIR__)

defmodule ToolchainMetadata do
  @filename "toolchain-builder.metadata"
  @hosts %{
    "linux_x86_64" => "x86_64-linux-gnu",
    "linux_aarch64" => "aarch64-linux-gnu",
    "darwin_x86_64" => "x86_64-apple-darwin",
    "darwin_arm" => "aarch64-apple-darwin"
  }
  @excluded_versions ~w(CT_CONFIG_VERSION CT_TOOLCHAIN_PKGVERSION CT_GLIBC_MIN_KERNEL_VERSION)

  def prepare!(install, host) do
    config = ToolchainDefconfig.read!(Path.join(install, "ct-ng.config"))
    [compiler] = Path.wildcard(Path.join(install, "bin/*-gcc"))

    libc =
      cond do
        config["CT_LIBC_MUSL"] == "y" -> "musl"
        config["CT_LIBC_GLIBC"] == "y" -> "glibc"
        true -> raise "Expected glibc or musl in ct-ng.config"
      end

    versions =
      for {"CT_" <> key = original, "\"" <> value} <- config,
          String.ends_with?(key, "_VERSION"),
          original not in @excluded_versions,
          version = String.trim_trailing(value, "\""),
          version != "",
          into: %{} do
        {key |> String.trim_trailing("_VERSION") |> String.downcase(), version}
      end

    metadata =
      Map.merge(versions, %{
        "target" => Path.basename(compiler, "-gcc"),
        "host" => Map.fetch!(@hosts, host),
        "release" => File.read!(Path.join(install, "toolchain-builder.version")) |> String.trim(),
        "libc" => libc
      })
      |> validate!()

    File.write!(Path.join(install, @filename), contents(metadata))
    metadata
  end

  def read_archive!(archive) do
    tar = if match?({:unix, :darwin}, :os.type()), do: "gtar", else: "tar"

    # tar stops after metadata, so zstd's resulting broken pipe is expected.
    # Use tar's exit status; inspecting metadata is not an archive integrity check.
    {output, status} =
      System.cmd("bash", [
        "-c",
        ~S(zstd -dqqc -- "$1" | "$2" -xOf - --wildcards --occurrence=1 -- "$3"),
        "archive",
        Path.expand(archive),
        tar,
        "*/#{@filename}"
      ])

    if status != 0, do: raise("Cannot read toolchain metadata from #{archive}")

    output
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      case String.split(line, "=", parts: 2) do
        [key, value] -> {key, value}
        _ -> raise "Invalid toolchain metadata"
      end
    end)
    |> Map.new()
    |> validate!()
  end

  def archive_name(metadata) do
    metadata = validate!(metadata)

    "#{metadata["target"]}--gcc-#{metadata["gcc"]}-#{metadata["libc"]}-" <>
      "#{metadata[metadata["libc"]]}-linux-#{metadata["linux"]}--" <>
      "#{metadata["release"]}--#{metadata["host"]}.tar.zst"
  end

  def contents(metadata) do
    metadata
    |> Enum.sort()
    |> Enum.map_join(fn {key, value} -> "#{key}=#{value}\n" end)
  end

  defp validate!(metadata) do
    unless metadata["libc"] in ~w(glibc musl), do: raise("Invalid libc in toolchain metadata")

    for key <- ["target", "host", "release", "gcc", "linux", metadata["libc"]] do
      _ = Map.fetch!(metadata, key)
    end

    unless Enum.all?(metadata, fn {key, value} ->
             Regex.match?(~r/^[a-z][a-z0-9_]*$/, key) and
               Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9_.+-]*$/, value)
           end),
           do: raise("Invalid toolchain metadata")

    unless metadata["host"] in Map.values(@hosts),
      do: raise("Invalid host in toolchain metadata")

    unless Regex.match?(~r/^\d{4}\.(?:0[1-9]|1[0-2])\.[1-9]\d*$/, metadata["release"]),
      do: raise("Release must be a calendar version YYYY.MM.N")

    metadata
  end
end
