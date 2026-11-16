#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../crosstool_ng.exs", __DIR__)
IO.puts(CrosstoolNG.ensure!())
