#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("metadata.exs", __DIR__)
[app, host] = System.argv()
{native, compatibility} = ToolchainMetadata.archive_names(app, host)
IO.puts("#{native} #{compatibility}")
