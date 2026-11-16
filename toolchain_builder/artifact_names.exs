#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("metadata.exs", __DIR__)

case System.argv() do
  [toolchain] -> IO.write(ToolchainMetadata.contents(toolchain))
  [toolchain, host] -> IO.puts(ToolchainMetadata.archive_name(toolchain, host))
end
