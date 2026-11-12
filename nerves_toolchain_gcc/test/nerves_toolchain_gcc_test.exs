# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

defmodule NervesToolchainGCCTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlan

  setup context do
    if tmp_dir = context[:tmp_dir], do: on_exit(fn -> File.rm_rf!(tmp_dir) end)
    override = System.get_env("NERVES_TOOLCHAIN")
    System.delete_env("NERVES_TOOLCHAIN")

    on_exit(fn ->
      if override,
        do: System.put_env("NERVES_TOOLCHAIN", override),
        else: System.delete_env("NERVES_TOOLCHAIN")
    end)

    :ok
  end

  test "compiler releases have independent caches without changing the Mix package version" do
    first = configure("https://example.com/gcc-14.tar.xz")
    second = configure("https://example.com/gcc-15.tar.xz")
    one = BuildPlan.find_package(first, :nerves_toolchain_gcc)
    two = BuildPlan.find_package(second, :nerves_toolchain_gcc)

    assert one.version == two.version
    refute one.artifact_path == two.artifact_path
    refute one.download_path == two.download_path
    refute one.source_fingerprint == two.source_fingerprint
    assert hd(one.downloads).filename == "gcc-14.tar.xz"
    assert first.env == %{}
    assert configure("https://example.com/gcc-14.tar.xz") == first
  end

  test "selects native macOS artifacts rather than Linux container artifacts" do
    plan = plan("aarch64-apple-darwin25.0")
    opts = [archives: %{"aarch64-apple-darwin" => "https://example.com/darwin.tar.xz"}]
    configured = NervesToolchainGCC.pre_download(plan, opts)
    package = BuildPlan.find_package(configured, :nerves_toolchain_gcc)
    assert hd(package.downloads).filename == "darwin.tar.xz"
  end

  test "rejects unavailable hosts and conflicting system selections" do
    assert_raise Mix.Error, ~r/No GCC toolchain archive configured/, fn ->
      NervesToolchainGCC.pre_download(plan(), archives: %{})
    end

    configured = configure("https://example.com/gcc-14.tar.xz")

    assert_raise Mix.Error, ~r/Multiple GCC toolchains selected/, fn ->
      NervesToolchainGCC.pre_download(configured,
        archives: %{"x86_64-linux-gnu" => "https://example.com/gcc-15.tar.xz"}
      )
    end
  end

  @tag :tmp_dir
  test "extracts an archive and activates a discovered GCC prefix", %{tmp_dir: tmp_dir} do
    configured = configure("https://example.com/arm-toolchain.tar.gz")
    package = BuildPlan.find_package(configured, :nerves_toolchain_gcc)
    package = %{package | artifact_path: Path.join(tmp_dir, "artifact"), download_path: tmp_dir}
    archive_path = Path.join(tmp_dir, "arm-toolchain.tar.gz")

    :ok =
      :erl_tar.create(
        String.to_charlist(archive_path),
        [{~c"toolchain/bin/arm-example-linux-musleabihf-gcc", "compiler"}],
        [:compressed]
      )

    [download] = package.downloads

    package = %{
      package
      | downloads: [%{download | archive_path: archive_path}],
        extractors: [{:untar, source: archive_path, destination: package.artifact_path}]
    }

    activated =
      configured
      |> BuildPlan.replace_package(package)
      |> Nerves.ArtifactResolver.resolve()
      |> NervesToolchainGCC.post_extract([])

    env = BuildPlan.fetch_interpolated_env!(activated)
    prefix = Path.join(package.artifact_path, "bin/arm-example-linux-musleabihf")
    assert env["CC"] == "#{prefix}-gcc"
    assert env["CXX"] == "#{prefix}-g++"
    assert env["AR"] == "#{prefix}-ar"
    assert env["REBAR_TARGET_ARCH"] == "arm-example-linux-musleabihf"
    assert env["NERVES_TOOLCHAIN"] == package.artifact_path
    assert String.starts_with?(env["PATH"], Path.join(package.artifact_path, "bin"))
  end

  @tag :tmp_dir
  test "supports local overrides and requires an explicit prefix when ambiguous", %{
    tmp_dir: tmp_dir
  } do
    File.mkdir_p!(Path.join(tmp_dir, "bin"))
    File.write!(Path.join(tmp_dir, "bin/arm-linux-gnu-gcc"), "")
    File.write!(Path.join(tmp_dir, "bin/arm-linux-musl-gcc"), "")
    System.put_env("NERVES_TOOLCHAIN", tmp_dir)
    configured = NervesToolchainGCC.pre_download(plan(), [])
    assert BuildPlan.find_package(configured, :nerves_toolchain_gcc).downloads == []

    assert_raise Mix.Error, ~r/Multiple GCC prefixes/, fn ->
      NervesToolchainGCC.post_extract(configured, [])
    end

    configured = NervesToolchainGCC.pre_download(plan(), prefix: "arm-linux-musl")
    activated = NervesToolchainGCC.post_extract(configured, [])
    assert activated.env["CROSSCOMPILE"] == Path.join(tmp_dir, "bin/arm-linux-musl")
  end

  @tag :tmp_dir
  @tag timeout: 120_000
  test "one Mix project resolves systems selecting different compiler releases", %{
    tmp_dir: tmp_dir
  } do
    integration_path = File.cwd!()

    for {app, compiler} <- [system_one: "gcc-14", system_two: "gcc-15"] do
      path = Path.join(tmp_dir, to_string(app))
      File.mkdir_p!(path)

      archives =
        Map.new(
          [
            "x86_64-linux-gnu",
            "aarch64-linux-gnu",
            "x86_64-apple-darwin",
            "aarch64-apple-darwin"
          ],
          &{&1, "https://example.com/#{compiler}.tar.xz"}
        )

      File.write!(Path.join(path, "mix.exs"), """
      defmodule #{Macro.camelize(to_string(app))}.MixProject do
        use Mix.Project
        def project do
          [
            app: #{inspect(app)},
            version: "0.1.0",
            nerves: [actions: [{NervesToolchainGCC, archives: #{inspect(archives)}}]],
            deps: [
              {:nerves_toolchain_gcc, path: #{inspect(integration_path)}, runtime: false}
            ]
          ]
        end
      end
      """)
    end

    overrides =
      Mix.Project.deps_paths()
      |> Map.take([:nerves, :interactive_cmd, :nerves_discovery, :tablet])
      |> Enum.map(fn {app, path} -> {app, [path: path, override: true, runtime: false]} end)

    deps =
      overrides ++
        [
          {:system_one, [path: "system_one", targets: :one, runtime: false]},
          {:system_two, [path: "system_two", targets: :two, runtime: false]}
        ]

    File.write!(Path.join(tmp_dir, "mix.exs"), """
    defmodule TwoSystems.MixProject do
      use Mix.Project
      def project, do: [app: :two_systems, version: "0.1.0", deps: #{inspect(deps)}]
    end
    """)

    assert {output, 0} =
             System.cmd("mix", ["deps.get"],
               cd: tmp_dir,
               env: [{"MIX_TARGET", "one"}, {"MIX_ENV", "dev"}],
               stderr_to_stdout: true
             )

    refute output =~ "diverged"

    for {target, compiler} <- [{"one", "gcc-14"}, {"two", "gcc-15"}] do
      command = """
      plan = Nerves.build_plan()
      package = Nerves.BuildPlan.find_package(plan, :nerves_toolchain_gcc)
      IO.puts("SELECTED_ARCHIVE=" <> hd(package.downloads).filename)
      """

      assert {output, 0} =
               System.cmd("mix", ["run", "-e", command],
                 cd: tmp_dir,
                 env: [{"MIX_TARGET", target}, {"MIX_ENV", "dev"}],
                 stderr_to_stdout: true
               )

      assert output =~ "SELECTED_ARCHIVE=#{compiler}.tar.xz"
    end
  end

  defp configure(url) do
    NervesToolchainGCC.pre_download(plan(), archives: %{"x86_64-linux-gnu" => url})
  end

  defp plan(tuple \\ "x86_64-pc-linux-gnu") do
    %BuildPlan{
      config: %{host_tuple: Nerves.TargetTuple.new(tuple)},
      env: %{},
      packages: [
        %{
          app: :nerves_toolchain_gcc,
          version: "0.1.0",
          path: File.cwd!(),
          validated_files: []
        }
      ]
    }
  end
end
