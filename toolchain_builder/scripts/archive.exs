#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../metadata.exs", __DIR__)

case System.argv() do
  ["--check-config", base, resolved] ->
    ToolchainMetadata.check_config!(base, resolved)

  ["--find", directory, config, host, release] ->
    if archive = ToolchainMetadata.find_archive(directory, config, host, release),
      do: IO.puts(archive)

  ["--prepare", install, host] ->
    install |> ToolchainMetadata.prepare!(host) |> ToolchainMetadata.archive_name() |> IO.puts()

  ["--name", archive] ->
    archive |> ToolchainMetadata.read_archive!() |> ToolchainMetadata.archive_name() |> IO.puts()

  [archive] ->
    archive |> ToolchainMetadata.read_archive!() |> ToolchainMetadata.contents() |> IO.write()

  _ ->
    IO.puts(:stderr, "Usage: elixir scripts/archive.exs [--name] <archive.tar.xz>")
    System.halt(1)
end
