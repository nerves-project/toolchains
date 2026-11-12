# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

defmodule NervesToolchainGCC.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_toolchain_gcc,
      version: "0.1.0",
      elixir: "~> 1.17",
      description: "GCC toolchain artifact integration for Nerves 2",
      source_url: "https://github.com/nerves-project/toolchains",
      nerves: [artifact_source_files: ["lib", "mix.exs"]],
      deps: [
        {:nerves, "~> 2.0.0-pre.9", runtime: false},
        {:ex_doc, "~> 0.22", only: :docs, runtime: false}
      ],
      package: [
        files: ["lib", "mix.exs", "README.md", "LICENSE"],
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => "https://github.com/nerves-project/toolchains"}
      ],
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def application, do: []

  def cli do
    [preferred_envs: %{docs: :docs, "hex.build": :docs, "hex.publish": :docs}]
  end
end
