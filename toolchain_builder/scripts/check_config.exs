#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../defconfig.exs", __DIR__)
[base, resolved] = System.argv()
ToolchainDefconfig.validate!(base, resolved)
