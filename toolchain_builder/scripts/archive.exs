#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../metadata.exs", __DIR__)

case System.argv() do
  ["--prepare", install, host] ->
    ToolchainMetadata.prepare!(install, host)

  ["--name", archive] ->
    archive |> ToolchainMetadata.read_archive!() |> ToolchainMetadata.archive_name() |> IO.puts()

  [archive] ->
    archive |> ToolchainMetadata.read_archive!() |> ToolchainMetadata.contents() |> IO.write()

  _ ->
    IO.puts(:stderr, "Usage: elixir scripts/archive.exs [--name] <archive.tar.zst>")
    System.halt(1)
end
