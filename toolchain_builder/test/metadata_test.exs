# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../metadata.exs", __DIR__)
ExUnit.start()

defmodule ToolchainMetadataTest do
  use ExUnit.Case

  @target "test-nerves-linux-gnu"
  @release "2026.11.1"
  @tar if(match?({:unix, :darwin}, :os.type()), do: "gtar", else: "tar")
  @package Path.expand("../scripts/package.sh", __DIR__)
  @inspect_archive Path.expand("../scripts/archive.exs", __DIR__)

  defp install!(tmp_dir, libc \\ "glibc") do
    install = Path.join(tmp_dir, "installed")
    File.mkdir_p!(Path.join(install, "bin"))
    File.write!(Path.join(install, "bin/#{@target}-gcc"), "compiler")
    File.ln_s!("#{@target}-gcc", Path.join(install, "bin/#{@target}-cc"))
    File.write!(Path.join(install, "toolchain-builder.version"), @release <> "\n")

    File.write!(Path.join(install, "ct-ng.config"), """
    CT_CONFIG_VERSION="4"
    CT_GCC_VERSION="99.2.1"
    CT_BINUTILS_VERSION="2.99"
    CT_LINUX_VERSION="6.12.3"
    CT_LIBC_#{String.upcase(libc)}=y
    CT_#{String.upcase(libc)}_VERSION="2.99"
    CT_GLIBC_MIN_KERNEL_VERSION="5.10.0"
    CT_GMP_VERSION="6.3.0"
    CT_OPTIONAL_VERSION=""
    CT_GDB_CUSTOM_VERSION=y
    """)

    install
  end

  defp package!(install, output, host \\ "linux_x86_64") do
    assert {_, 0} = System.cmd("bash", [@package, install, output, host], stderr_to_stdout: true)
    [archive] = Path.wildcard(Path.join(output, "*--#{host_suffix(host)}.tar.zst"))
    archive
  end

  defp host_suffix("linux_x86_64"), do: "x86_64-linux-gnu"
  defp host_suffix("darwin_arm"), do: "aarch64-apple-darwin"

  @tag :tmp_dir
  test "packaging uses resolved versions, preserves the install tree, and refuses replacement",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir)
    output = Path.join(tmp_dir, "archives")
    archive_path = package!(install, output)
    native = Path.basename(archive_path)
    assert Enum.sort(File.ls!(output)) == Enum.sort([native, native <> ".sha256"])

    assert native ==
             "#{@target}--gcc-99.2.1-glibc-2.99-linux-6.12.3--#{@release}--x86_64-linux-gnu.tar.zst"

    archive = File.read!(archive_path)
    digest = :crypto.hash(:sha256, archive) |> Base.encode16(case: :lower)
    assert File.read!(Path.join(output, native <> ".sha256")) == "#{digest}  #{native}\n"
    assert File.read!(Path.join(install, "bin/#{@target}-gcc")) == "compiler"
    assert File.read_link!(Path.join(install, "bin/#{@target}-cc")) == "#{@target}-gcc"

    {listing, 0} = System.cmd(@tar, ["--zstd", "-tf", archive_path])
    members = String.split(listing, "\n", trim: true)
    assert hd(members) == "installed/toolchain-builder.metadata"
    assert Enum.count(members, &(&1 == hd(members))) == 1

    extracted = Path.join(tmp_dir, "extracted")
    File.mkdir_p!(extracted)

    assert {_, 0} =
             System.cmd(@tar, [
               "xf",
               archive_path,
               "--strip-components=1",
               "-C",
               extracted
             ])

    assert File.read!(Path.join(extracted, "bin/#{@target}-gcc")) == "compiler"
    assert File.read_link!(Path.join(extracted, "bin/#{@target}-cc")) == "#{@target}-gcc"

    File.write!(Path.join(install, "bin/#{@target}-gcc"), "different compiler")

    assert {message, 1} =
             System.cmd("bash", [@package, install, output, "linux_x86_64"],
               stderr_to_stdout: true
             )

    assert message =~ "Archive already exists"
    assert File.read!(archive_path) == archive
    assert File.read!(Path.join(install, "bin/#{@target}-gcc")) == "different compiler"

    later_host = package!(install, output, "darwin_arm") |> Path.basename()
    assert later_host == String.replace(native, "--x86_64-linux-gnu", "--aarch64-apple-darwin")
    assert File.read!(archive_path) == archive

    assert Enum.sort(File.ls!(output)) ==
             Enum.sort([native, native <> ".sha256", later_host, later_host <> ".sha256"])
  end

  @tag :tmp_dir
  test "inspection reads a renamed archive without an installation or extracting files",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir, "musl")
    File.write!(Path.join(install, "payload"), :crypto.strong_rand_bytes(1024 * 1024))
    archive = package!(install, Path.join(tmp_dir, "archives"), "darwin_arm")
    original_name = Path.basename(archive)
    renamed = Path.join(tmp_dir, "unrelated name.tar.zst")
    File.rename!(archive, renamed)
    File.rm_rf!(install)
    before = Path.wildcard(Path.join(tmp_dir, "**/*"), match_dot: true)

    metadata = ToolchainMetadata.read_archive!(renamed)
    assert metadata["target"] == @target
    assert metadata["host"] == "aarch64-apple-darwin"
    assert metadata["release"] == @release
    assert metadata["libc"] == "musl"
    assert metadata["musl"] == "2.99"
    assert metadata["binutils"] == "2.99"
    assert metadata["gmp"] == "6.3.0"
    refute Map.has_key?(metadata, "config")
    refute Map.has_key?(metadata, "glibc_min_kernel")
    refute Map.has_key?(metadata, "optional")
    refute Map.has_key?(metadata, "gdb_custom")
    assert ToolchainMetadata.archive_name(metadata) == original_name

    assert {report, 0} = System.cmd("elixir", [@inspect_archive, renamed])
    assert report == ToolchainMetadata.contents(metadata)

    assert {name, 0} = System.cmd("elixir", [@inspect_archive, "--name", renamed])
    assert String.trim(name) == original_name
    assert Path.wildcard(Path.join(tmp_dir, "**/*"), match_dot: true) == before
  end

  @tag :tmp_dir
  test "inspection rejects malformed metadata and unsafe archive names", %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir)
    metadata = ToolchainMetadata.prepare!(install, "linux_x86_64")

    for contents <- [
          metadata |> Map.put("target", "../outside") |> ToolchainMetadata.contents(),
          "not metadata\n"
        ] do
      File.write!(Path.join(install, "toolchain-builder.metadata"), contents)
      archive = Path.join(tmp_dir, "invalid.tar.zst")

      assert {_, 0} =
               System.cmd(@tar, [
                 "--zstd",
                 "-cf",
                 archive,
                 "-C",
                 tmp_dir,
                 "installed/toolchain-builder.metadata"
               ])

      assert_raise RuntimeError, ~r/Invalid toolchain metadata/, fn ->
        ToolchainMetadata.read_archive!(archive)
      end
    end
  end

  @tag :tmp_dir
  test "compression failure leaves the installation in place without publishing",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir)
    output = Path.join(tmp_dir, "archives")
    zstd = Path.join(tmp_dir, "zstd")
    File.write!(zstd, "#!/bin/sh\nexit 9\n")
    File.chmod!(zstd, 0o755)

    assert {_, status} =
             System.cmd("bash", [@package, install, output, "linux_x86_64"],
               env: [{"PATH", "#{tmp_dir}:#{System.fetch_env!("PATH")}"}],
               stderr_to_stdout: true
             )

    assert status != 0
    assert File.ls!(output) == []
    assert File.read!(Path.join(install, "bin/#{@target}-gcc")) == "compiler"
  end

  @tag :tmp_dir
  test "smoke test verifies and relocates an archive before compiling", %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir)
    compiler = Path.join(install, "bin/#{@target}-g++")

    File.write!(compiler, """
    #!/usr/bin/env bash
    args=()
    for arg; do
        if [[ "$arg" != -Wl,--build-id=none ]]; then args+=("$arg"); fi
    done
    exec c++ "${args[@]}"
    """)

    File.chmod!(compiler, 0o755)
    archive = package!(install, Path.join(tmp_dir, "archives"))
    executable = Path.join(tmp_dir, "smoketest.elf")
    script = Path.expand("smoketest.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, archive, executable], stderr_to_stdout: true)
    assert File.regular?(executable)
    File.rm!(executable)
    File.write!(archive, "corrupted")
    assert {_, status} = System.cmd("bash", [script, archive, executable], stderr_to_stdout: true)
    assert status != 0
    refute File.exists?(executable)
  end

  @tag :tmp_dir
  test "explicit defaults are validated against the resolved config, not savedefconfig",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    base = Path.join(tmp_dir, "base")
    resolved = Path.join(tmp_dir, ".config")

    File.write!(
      base,
      "CT_GCC_V_15=y\nCT_GCC_VERSION=\"15.3.0\"\n# CT_CREATE_LDSO_CONF is not set\n"
    )

    File.write!(
      resolved,
      "# CT_CREATE_LDSO_CONF is not set\nCT_GCC_VERSION=\"15.3.0\"\nCT_GCC_V_15=y\nCT_STATIC_TOOLCHAIN=y\n"
    )

    assert :ok = ToolchainDefconfig.validate!(base, resolved)

    File.write!(
      resolved,
      "# CT_CREATE_LDSO_CONF is not set\nCT_GCC_VERSION=\"15.4.0\"\nCT_GCC_V_15=y\nCT_STATIC_TOOLCHAIN=y\n"
    )

    assert_raise RuntimeError, ~r/CT_GCC_VERSION: requested "15.3.0", resolved "15.4.0"/, fn ->
      ToolchainDefconfig.validate!(base, resolved)
    end

    assert File.read!(base) =~ "CT_GCC_VERSION=\"15.3.0\""
  end
end
