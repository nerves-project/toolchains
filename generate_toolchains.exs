#!/usr/bin/env elixir

# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("toolchain_builder/metadata.exs", __DIR__)

defmodule ToolchainGenerator do
  @moduledoc """
  Generates toolchain packages from template using EEx
  """

  @version_metadata_path Path.join(__DIR__, "toolchain_builder/toolchain_versions.exs")
  @component_licenses %{
    "GCC" => "GPL-3.0-or-later",
    "binutils" => "GPL-3.0-or-later",
    "Linux headers" => "GPL-2.0-only WITH Linux-syscall-note",
    "glibc" => "LGPL-2.1-or-later",
    "musl" => "MIT",
    "GDB" => "GPL-3.0-or-later",
    "expat" => "MIT",
    "gettext" => "GPL-3.0-or-later",
    "GMP" => "LGPL-3.0-or-later OR GPL-2.0-or-later",
    "ISL" => "MIT",
    "libiconv" => "LGPL-2.1-or-later",
    "MPC" => "LGPL-3.0-or-later",
    "MPFR" => "LGPL-3.0-or-later",
    "ncurses" => "MIT",
    "zlib" => "Zlib",
    "bison" => "GPL-3.0-or-later",
    "m4" => "GPL-3.0-or-later"
  }

  # Toolchain configuration
  @toolchains [
    :aarch64_nerves_linux_gnu,
    :aarch64_nerves_linux_musl,
    :armv5_nerves_linux_musleabi,
    :armv6_nerves_linux_gnueabihf,
    :armv7_nerves_linux_gnueabihf,
    :armv7_nerves_linux_musleabihf,
    :i586_nerves_linux_gnu,
    :mipsel_nerves_linux_musl,
    :riscv64_nerves_linux_gnu,
    :riscv64_nerves_linux_musl,
    :x86_64_nerves_linux_gnu,
    :x86_64_nerves_linux_musl
  ]

  def run do
    IO.puts("Generating toolchain packages from template...")

    version_metadata = load_version_metadata()

    Enum.each(@toolchains, &generate_toolchain(&1, version_metadata))

    IO.puts("\nGenerated #{length(@toolchains)} toolchain packages")
  end

  defp generate_toolchain(target_tuple, version_metadata) when is_atom(target_tuple) do
    app_name = "nerves_toolchain_#{target_tuple}"
    target_display = target_tuple |> to_string() |> String.replace("_", "-")
    target_display = String.replace_prefix(target_display, "x86-64-", "x86_64-")
    config_name = "#{target_display}--gcc15"
    target_dir = Path.expand(app_name)
    versions = Map.get(version_metadata, config_name, [])

    IO.puts("Generating #{target_dir}...")

    # Create directory if it doesn't exist
    File.mkdir_p!(target_dir)

    for obsolete <- [
          "build.sh",
          "defconfig",
          "defaults",
          "scripts",
          "patches",
          "Dockerfile",
          "nerves-artifact"
        ] do
      File.rm_rf!(Path.join(target_dir, obsolete))
    end

    File.write!(Path.join(target_dir, "toolchain.exs"), ToolchainMetadata.contents(config_name))

    # Prepare bindings for EEx templates
    module_name = target_tuple_to_module_name(target_tuple)
    included_components = build_included_components(versions)
    package_licenses_list = format_string_list(build_package_licenses(included_components))
    external_toolchain_settings = build_external_toolchain_settings!(versions)

    bindings = [
      module_name: module_name,
      app_name: app_name,
      target_tuple: target_tuple,
      target_display: target_display,
      toolchain_metadata: ToolchainMetadata.metadata(config_name),
      included_components: included_components,
      package_licenses_list: package_licenses_list,
      linux_headers_series: external_toolchain_settings.linux_headers_series,
      libc_type: external_toolchain_settings.libc_type
    ]

    template_dir = Path.expand("template")

    template_files = Path.wildcard(Path.join(template_dir, "**"), match_dot: true)

    pairs =
      Enum.map(template_files, fn path ->
        {path, String.replace_prefix(path, template_dir, target_dir)}
      end)

    Enum.each(pairs, &process_files(&1, bindings))
  end

  defp target_tuple_to_module_name(target_tuple) do
    target_tuple
    |> to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
    |> then(&"NervesToolchain#{&1}")
  end

  defp process_files({from_path, to_path}, bindings) do
    expanded_to_path = expand_output_path(to_path, bindings)

    cond do
      String.ends_with?(from_path, ".eex") ->
        output_path = String.replace_suffix(expanded_to_path, ".eex", "")
        content = EEx.eval_file(from_path, assigns: bindings)

        content =
          if Path.extname(output_path) in [".ex", ".exs"] do
            IO.iodata_to_binary(Code.format_string!(content)) <> "\n"
          else
            content
          end

        File.write!(output_path, content)

      File.dir?(from_path) ->
        File.mkdir_p!(expanded_to_path)

      true ->
        File.cp!(from_path, expanded_to_path)
    end
  end

  defp expand_output_path(path, bindings) do
    String.replace(path, "package_name", Keyword.fetch!(bindings, :app_name))
  end

  defp build_included_components(versions) do
    Enum.map(versions, fn {component, version} ->
      {component, version, component_license!(component)}
    end)
  end

  defp build_external_toolchain_settings!(versions) do
    versions_by_component = Map.new(versions)

    %{
      linux_headers_series: linux_headers_series!(versions_by_component),
      libc_type: libc_type!(versions_by_component)
    }
  end

  defp linux_headers_series!(versions_by_component) do
    versions_by_component
    |> Map.fetch!("Linux headers")
    |> String.split(".")
    |> Enum.take(2)
    |> case do
      [major, minor] -> "#{major}_#{minor}"
      _ -> raise "expected Linux headers version to include major and minor numbers"
    end
  end

  defp libc_type!(versions_by_component) do
    cond do
      Map.has_key?(versions_by_component, "glibc") -> "GLIBC"
      Map.has_key?(versions_by_component, "musl") -> "MUSL"
      true -> raise "expected glibc or musl in toolchain version metadata"
    end
  end

  defp build_package_licenses(included_components) do
    included_components
    |> Enum.map(&elem(&1, 2))
    |> Enum.map(&package_license/1)
    |> Enum.uniq()
  end

  defp package_license("GPL-2.0-only WITH Linux-syscall-note"), do: "GPL-2.0-only"
  defp package_license("LGPL-3.0-or-later OR GPL-2.0-or-later"), do: "LGPL-3.0-or-later"
  defp package_license(license), do: license

  defp component_license!(component) do
    Map.fetch!(@component_licenses, component)
  end

  defp format_string_list(values) do
    values
    |> Enum.map(&inspect/1)
    |> Enum.join(",\n      ")
  end

  defp load_version_metadata do
    if File.exists?(@version_metadata_path) do
      {metadata, _bindings} = Code.eval_file(@version_metadata_path)

      if is_map(metadata) do
        metadata
      else
        %{}
      end
    else
      %{}
    end
  end
end

ToolchainGenerator.run()
