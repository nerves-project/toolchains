# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../toolchain.exs", __DIR__)
ExUnit.start()

defmodule ToolchainTest do
  use ExUnit.Case

  @target "test-nerves-linux-gnu"
  @release File.read!(Path.expand("../VERSION", __DIR__)) |> String.trim()
  @tar if(match?({:unix, :darwin}, :os.type()), do: "gtar", else: "tar")
  @package Path.expand("../scripts/package.sh", __DIR__)
  @archive Path.expand("../scripts/archive.exs", __DIR__)

  defp install!(tmp_dir, libc \\ "glibc") do
    install = Path.join(tmp_dir, "installed")
    File.mkdir_p!(Path.join(install, "bin"))
    File.write!(Path.join(install, "bin/#{@target}-gcc"), "compiler")
    File.ln_s!("#{@target}-gcc", Path.join(install, "bin/#{@target}-cc"))

    File.write!(Path.join(install, "ct-ng.config"), """
    CT_CONFIG_VERSION="4"
    CT_GCC_VERSION="99.2.1"
    CT_BINUTILS_VERSION="2.99"
    CT_LINUX_VERSION="6.12.3"
    CT_LIBC_#{String.upcase(libc)}=y
    CT_#{String.upcase(libc)}_VERSION="2.99"
    CT_GLIBC_MIN_KERNEL_VERSION="6.1.0"
    CT_GMP_VERSION="6.3.0"
    CT_OPTIONAL_VERSION=""
    CT_GDB_CUSTOM_VERSION=y
    """)

    install
  end

  defp package!(install, output, host \\ "linux_x86_64") do
    assert {_, 0} = System.cmd("bash", [@package, install, output, host], stderr_to_stdout: true)
    [archive] = Path.wildcard(Path.join(output, "*--#{host}.tar.xz"))
    archive
  end

  @tag :tmp_dir
  test "packaging uses resolved versions, preserves the install tree, and refuses replacement",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir)
    File.write!(Path.join(install, "toolchain-builder.metadata"), "stale metadata\n")
    File.write!(Path.join(install, "toolchain-builder.version"), "2000.01.1\n")
    recipe = Path.join(install, "share/toolchain-builder")
    File.mkdir_p!(recipe)
    File.write!(Path.join(recipe, "build-info.json"), "{}")
    output = Path.join(tmp_dir, "archives")
    archive_path = package!(install, output)
    native = Path.basename(archive_path)
    config = @target <> "--gcc99"

    assert Toolchain.find_archive(output, config, "linux_x86_64", @release) ==
             archive_path

    refute Toolchain.find_archive(output, config, "darwin_arm", @release)
    refute Toolchain.find_archive(output, config, "linux_x86_64", "2026.11.2")
    refute Toolchain.find_archive(output, @target <> "--gcc15", "linux_x86_64", @release)
    File.rename!(archive_path <> ".sha256", archive_path <> ".saved")
    refute Toolchain.find_archive(output, config, "linux_x86_64", @release)
    File.rename!(archive_path <> ".saved", archive_path <> ".sha256")
    assert Enum.sort(File.ls!(output)) == Enum.sort([native, native <> ".sha256"])

    assert native ==
             "#{@target}--gcc-99.2.1-glibc-2.99-linux-6.12.3--#{@release}--linux_x86_64.tar.xz"

    archive = File.read!(archive_path)
    digest = :crypto.hash(:sha256, archive) |> Base.encode16(case: :lower)
    assert File.read!(Path.join(output, native <> ".sha256")) == "#{digest}  #{native}\n"
    assert File.read!(Path.join(install, "bin/#{@target}-gcc")) == "compiler"
    assert File.read_link!(Path.join(install, "bin/#{@target}-cc")) == "#{@target}-gcc"

    {listing, 0} = System.cmd(@tar, ["-tJf", archive_path])
    members = String.split(listing, "\n", trim: true)
    refute "installed/toolchain-builder.metadata" in members
    refute "installed/share/toolchain-builder/build-info.json" in members
    assert "installed/ct-ng.config" in members
    refute "installed/toolchain-builder.version" in members
    assert File.read!(Path.join(install, "toolchain-builder.metadata")) == "stale metadata\n"

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
    assert later_host == String.replace(native, "--linux_x86_64", "--darwin_arm")
    assert File.read!(archive_path) == archive

    assert Enum.sort(File.ls!(output)) ==
             Enum.sort([native, native <> ".sha256", later_host, later_host <> ".sha256"])
  end

  @tag :tmp_dir
  test "archive naming reads the installation without creating metadata",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir, "musl")
    before = Path.wildcard(Path.join(tmp_dir, "**/*"), match_dot: true)

    assert {name, 0} = System.cmd("elixir", [@archive, "--name", install, "darwin_arm"])

    assert String.trim(name) ==
             "#{@target}--gcc-99.2.1-musl-2.99-linux-6.12.3--#{@release}--darwin_arm.tar.xz"

    assert Path.wildcard(Path.join(tmp_dir, "**/*"), match_dot: true) == before
    archive = package!(install, Path.join(tmp_dir, "archives"), "darwin_arm")
    assert Path.basename(archive) == String.trim(name)
    refute File.exists?(Path.join(install, "toolchain-builder.metadata"))
    refute File.exists?(Path.join(install, "toolchain-builder.version"))
  end

  @tag :tmp_dir
  test "archive naming rejects unsafe component versions", %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir)
    config = Path.join(install, "ct-ng.config")
    File.write!(config, String.replace(File.read!(config), "99.2.1", "../outside"))

    assert_raise RuntimeError, ~r/Invalid archive name component/, fn ->
      Toolchain.archive_name(install, "linux_x86_64")
    end
  end

  @tag :tmp_dir
  test "compression failure leaves the installation in place without publishing",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    install = install!(tmp_dir)
    output = Path.join(tmp_dir, "archives")
    xz = Path.join(tmp_dir, "xz")
    File.write!(xz, "#!/bin/sh\nexit 9\n")
    File.chmod!(xz, 0o755)

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

    assert :ok = Toolchain.check_config!(base, resolved)

    File.write!(
      resolved,
      "# CT_CREATE_LDSO_CONF is not set\nCT_GCC_VERSION=\"15.4.0\"\nCT_GCC_V_15=y\nCT_STATIC_TOOLCHAIN=y\n"
    )

    assert_raise RuntimeError, ~r/CT_GCC_VERSION: requested "15.3.0", resolved "15.4.0"/, fn ->
      Toolchain.check_config!(base, resolved)
    end

    assert File.read!(base) =~ "CT_GCC_VERSION=\"15.3.0\""
  end
end
