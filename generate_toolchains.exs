#!/usr/bin/env elixir

# Generator script to create toolchain packages from template
# This embeds the nerves_toolchain_ctng code directly into each package

defmodule ToolchainGenerator do
  @moduledoc """
  Generates toolchain packages from template using EEx
  """

  @toolchain_config_path Path.expand("toolchain_config.exs")
  @version_metadata_path Path.expand("configs/toolchain_versions.exs")
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

    toolchain_config = load_toolchain_config!()
    version_metadata = load_version_metadata()

    Enum.each(@toolchains, &generate_toolchain(&1, toolchain_config, version_metadata))

    IO.puts("\nGenerated #{length(@toolchains)} toolchain packages")
  end

  defp generate_toolchain(target_tuple, toolchain_config, version_metadata) when is_atom(target_tuple) do
    app_name = "nerves_toolchain_#{target_tuple}"
    target_dir = Path.expand(app_name)
    config_dir = "configs/#{app_name}"

    IO.puts("Generating #{target_dir}...")

    # Create directory if it doesn't exist
    File.mkdir_p!(target_dir)

    # Copy essential files from configs directory
    copy_config_files(config_dir, target_dir)

    # Prepare bindings for EEx templates
    module_name = target_tuple_to_module_name(target_tuple)
    target_display = target_tuple |> to_string() |> String.replace("_", "-")
    package_files = ["defconfig", "README.md", "LICENSE", "mix.exs", "VERSION"]
    package_files_list = format_package_files(package_files)
    included_components = build_included_components(Map.get(version_metadata, app_name, []))
    package_licenses_list = format_string_list(build_package_licenses(included_components))

    bindings = [
      module_name: module_name,
      app_name: app_name,
      target_tuple: target_tuple,
      target_display: target_display,
      package_files_list: package_files_list,
      ctng_tag: Map.fetch!(toolchain_config, :ctng_tag),
      included_components: included_components,
      package_licenses_list: package_licenses_list
    ]

    template_dir = Path.expand("template")

    template_files = Path.wildcard(Path.join(template_dir, "**"), match_dot: true)

    pairs =
      Enum.map(template_files, fn path ->
        {path, String.replace_prefix(path, template_dir, target_dir)}
      end)

    Enum.each(pairs, &process_files(&1, bindings))
  end

  defp copy_config_files(config_dir, target_dir) do
    if File.dir?(config_dir) do
      File.ls!(config_dir)
      |> Enum.each(fn file ->
        File.cp!(Path.join(config_dir, file), Path.join(target_dir, file))
      end)
    end
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

  defp format_package_files(files), do: format_string_list(files)

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

  defp load_toolchain_config! do
    {config, _bindings} = Code.eval_file(@toolchain_config_path)

    if is_map(config) and is_binary(Map.get(config, :ctng_tag)) do
      config
    else
      raise "toolchain_config.exs must return a map with a :ctng_tag string"
    end
  end
end

ToolchainGenerator.run()
