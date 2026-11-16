# SPDX-FileCopyrightText: None
# SPDX-License-Identifier: CC0-1.0
[
  inputs: [
    "generate_toolchains.exs",
    "nerves_toolchain*/mix.exs",
    "nerves_toolchain*/{config,lib,test}/**/*.{ex,exs}"
  ],
  subdirectories: ["toolchain_builder"]
]
