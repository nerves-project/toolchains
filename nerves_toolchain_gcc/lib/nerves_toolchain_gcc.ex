# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

defmodule NervesToolchainGCC do
  @moduledoc """
  Select a prebuilt GCC toolchain independently of Mix dependency versions.

  Register this build action in the system's `:nerves` configuration with an
  `:archives` map from host tuples to immutable archive URLs. See the README
  for a complete example. The optional `:prefix` selects a compiler when an
  archive provides multiple GCC prefixes.

  Archives contain a single top-level directory with `bin/<prefix>-gcc`,
  its companion tools, and the compiler's sysroot. No compiler version or
  libc is imposed by this package. Builds happen outside Nerves.
  """

  use Nerves.BuildAction
  alias Nerves.BuildPlan
  alias Nerves.Paths

  @app :nerves_toolchain_gcc

  @impl Nerves.BuildAction
  def pre_download(plan, opts) do
    host = host_tuple(plan.config[:host_tuple])
    override = System.get_env("NERVES_TOOLCHAIN")
    override = if override in [nil, ""], do: nil, else: Path.expand(override)

    url =
      unless override do
        archives = Keyword.fetch!(opts, :archives)
        archives[host] || Mix.raise("No GCC toolchain archive configured for #{host}")
      end

    selection = %{host: host, url: url, prefix: opts[:prefix], override: override}

    case plan.config[@app] do
      ^selection ->
        plan

      nil ->
        configure_package(plan, selection)

      _ ->
        Mix.raise("Multiple GCC toolchains selected; enable only one Nerves system per target")
    end
  end

  defp configure_package(plan, selection) do
    package =
      BuildPlan.find_package(plan, @app) ||
        Mix.raise("Add :nerves_toolchain_gcc to the system's dependencies")

    identity =
      {selection.host, selection.url, selection.prefix, selection.override}
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    package =
      Map.merge(package, %{
        source_fingerprint: identity,
        download_path: Paths.download_dir(@app, identity),
        artifact_path: selection.override || Paths.artifact_dir(@app, identity),
        downloads: [],
        download_validators: [],
        extractors: []
      })

    package =
      if selection.override do
        unless File.dir?(selection.override),
          do: Mix.raise("$NERVES_TOOLCHAIN must point to an extracted artifact directory")

        package
      else
        configure_download(package, selection.url)
      end

    plan
    |> BuildPlan.replace_package(package)
    |> BuildPlan.merge_config(%{@app => selection})
  end

  defp configure_download(package, url) do
    uri = URI.new!(url)
    filename = Path.basename(uri.path || "")

    unless Nerves.Artifact.Archive.valid_name?(filename),
      do: Mix.raise("Unsupported GCC toolchain archive: #{url}")

    base_url = URI.to_string(%{uri | path: Path.dirname(uri.path), query: nil, fragment: nil})
    site_opts = if uri.query, do: [query_params: URI.decode_query(uri.query)], else: []
    archive_path = Path.join(package.download_path, filename)

    Map.merge(package, %{
      downloads: [
        %{
          archive_path: archive_path,
          filename: filename,
          sites: [{:prefix, base_url, site_opts}],
          version: package.version
        }
      ],
      download_validators: [{:archive, filename: filename}],
      extractors: [{:untar, source: archive_path, destination: package.artifact_path}]
    })
  end

  @impl Nerves.BuildAction
  def post_extract(plan, _opts) do
    package = BuildPlan.find_package(plan, @app)
    bin_path = Path.join(package.artifact_path, "bin")
    prefix = plan.config[@app].prefix

    compiler =
      if prefix do
        path = Path.join(bin_path, "#{prefix}-gcc")
        unless File.regular?(path), do: Mix.raise("Could not find GCC compiler #{path}")
        path
      else
        case Path.wildcard(Path.join(bin_path, "*-gcc")) do
          [path] -> path
          [] -> Mix.raise("Could not find a GCC cross-compiler in #{bin_path}")
          _ -> Mix.raise("Multiple GCC prefixes in #{bin_path}; configure :prefix explicitly")
        end
      end

    crosscompile = String.replace_suffix(compiler, "-gcc", "")

    plan
    |> BuildPlan.prepend_path(bin_path)
    |> BuildPlan.merge_env(%{
      "NERVES_TOOLCHAIN" => package.artifact_path,
      "CROSSCOMPILE" => crosscompile,
      "REBAR_TARGET_ARCH" => Path.basename(crosscompile),
      "AR" => "${CROSSCOMPILE}-ar",
      "AS" => "${CROSSCOMPILE}-as",
      "CC" => "${CROSSCOMPILE}-gcc",
      "CXX" => "${CROSSCOMPILE}-g++",
      "LD" => "${CROSSCOMPILE}-ld",
      "STRIP" => "${CROSSCOMPILE}-strip"
    })
  end

  defp host_tuple(%{os: "darwin" <> _, arch: arch}) when arch in ["aarch64", "x86_64"],
    do: "#{arch}-apple-darwin"

  defp host_tuple(%{os: "linux", arch: arch, abi: abi})
       when arch in ["aarch64", "x86_64"] and abi in ["gnu", "musl"],
       do: "#{arch}-linux-#{abi}"

  defp host_tuple(tuple), do: Mix.raise("Unsupported GCC toolchain host: #{inspect(tuple)}")
end
