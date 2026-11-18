#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../toolchain.exs", __DIR__)

case System.argv() do
  ["--check-config", base, resolved] ->
    Toolchain.check_config!(base, resolved)

  ["--find", directory, config, host, release] ->
    if archive = Toolchain.find_archive(directory, config, host, release),
      do: IO.puts(archive)

  ["--name", install, host] ->
    install |> Toolchain.archive_name(host) |> IO.puts()

  _ ->
    IO.puts(:stderr, "Usage: elixir scripts/archive.exs --name <installed toolchain> <host>")
    System.halt(1)
end
