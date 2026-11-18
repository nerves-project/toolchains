# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

defmodule Toolchain do
  def check_config!(target, resolved) do
    expected = read_config!(target)
    actual = read_config!(resolved)

    mismatches =
      for {key, value} <- Enum.sort(expected),
          Map.get(actual, key) != value do
        "#{key}: requested #{value}, resolved #{Map.get(actual, key, "<missing>")}"
      end

    if mismatches != [] do
      raise "crosstool-NG changed explicit configuration:\n" <> Enum.join(mismatches, "\n")
    end

    :ok
  end

  def find_archive(directory, config, host, release) do
    [target, "gcc" <> major] = String.split(config, "--")

    directory
    |> Path.join("#{target}--gcc-#{major}.*--#{release}--#{host}.tar.xz")
    |> Path.wildcard()
    |> Enum.find(&(File.regular?(&1) and File.regular?(&1 <> ".sha256")))
  end

  def archive_name(install, host) do
    config = read_config!(Path.join(install, "ct-ng.config"))
    [compiler] = Path.wildcard(Path.join(install, "bin/*-gcc"))

    libc =
      cond do
        config["CT_LIBC_MUSL"] == "y" -> "musl"
        config["CT_LIBC_GLIBC"] == "y" -> "glibc"
        true -> raise "Expected glibc or musl in ct-ng.config"
      end

    target = Path.basename(compiler, "-gcc")
    release = File.read!(Path.join(__DIR__, "VERSION")) |> String.trim()
    version = fn key -> config |> Map.fetch!(key) |> String.trim("\"") end
    gcc = version.("CT_GCC_VERSION")
    linux = version.("CT_LINUX_VERSION")
    libc_version = version.("CT_#{String.upcase(libc)}_VERSION")

    for value <- [target, host, gcc, linux, libc_version] do
      unless Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9_.+-]*$/, value),
        do: raise("Invalid archive name component: #{value}")
    end

    unless Regex.match?(~r/^\d{4}\.(?:0[1-9]|1[0-2])\.[1-9]\d*$/, release),
      do: raise("Release must be a calendar version YYYY.MM.N")

    "#{target}--gcc-#{gcc}-#{libc}-#{libc_version}-linux-#{linux}--#{release}--#{host}.tar.xz"
  end

  defp read_config!(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      cond do
        match = Regex.run(~r/^(CT_[A-Z0-9_]+)=(.*)$/, line) ->
          [_, key, value] = match
          [{key, value}]

        match = Regex.run(~r/^# (CT_[A-Z0-9_]+) is not set$/, line) ->
          [_, key] = match
          [{key, "n"}]

        true ->
          []
      end
    end)
    |> Map.new()
  end
end
