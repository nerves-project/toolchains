#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("metadata.exs", __DIR__)

case System.argv() do
  [toolchain] ->
    metadata = ToolchainMetadata.metadata(toolchain)
    archives = Enum.sort(metadata.archives) |> Enum.flat_map(fn {host, url} -> [host, url] end)

    {json, 0} =
      System.cmd("python3", [
        "-c",
        """
        import json, sys
        name, version, *pairs = sys.argv[1:]
        archives = dict(zip(pairs[::2], pairs[1::2]))
        print(json.dumps(dict(name=name, version=version, archives=archives), indent=2))
        """,
        metadata.name,
        metadata.version | archives
      ])

    IO.write(json)

  [toolchain, host] ->
    IO.puts(ToolchainMetadata.archive_name(toolchain, host))
end
