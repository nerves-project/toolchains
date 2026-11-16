# SPDX-FileCopyrightText: None
# SPDX-License-Identifier: CC0-1.0
[
  inputs: [
    "generate_toolchains.exs",
    "toolchain_builder/{metadata,artifact_names,update_versions,defconfig}.exs",
    "toolchain_builder/scripts/check_config.exs",
    "toolchain_builder/test/*.exs",
    "nerves_toolchain*/mix.exs",
    "nerves_toolchain*/{config,lib,test}/**/*.{ex,exs}"
  ]
]
