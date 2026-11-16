# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../metadata.exs", __DIR__)
ExUnit.start()

defmodule ToolchainMetadataTest do
  use ExUnit.Case

  @tag :tmp_dir
  test "packaging describes the components, preserves the install tree, and refuses replacement",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    toolchain = "armv7-nerves-linux-gnueabihf--gcc15"
    install = Path.join(tmp_dir, "installed")
    output = Path.join(tmp_dir, "archives")
    File.mkdir_p!(Path.join(install, "bin"))
    File.write!(Path.join(install, "bin/arm-gcc"), "compiler")
    File.ln_s!("arm-gcc", Path.join(install, "bin/arm-cc"))

    script = Path.expand("../scripts/package.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, install, output, toolchain, "linux_x86_64"])
    [native] = File.ls!(output)

    assert native =~
             ~r/^armv7-nerves-linux-gnueabihf--gcc-15\.3\.0-glibc-2\.43-linux-5\.10\.\d+--[\d.]+--x86_64-linux-gnu\.tar\.xz$/

    archive = File.read!(Path.join(output, native))
    assert File.read!(Path.join(install, "bin/arm-gcc")) == "compiler"
    assert File.read_link!(Path.join(install, "bin/arm-cc")) == "arm-gcc"

    extracted = Path.join(tmp_dir, "extracted")
    File.mkdir_p!(extracted)

    assert {_, 0} =
             System.cmd("tar", [
               "xf",
               Path.join(output, native),
               "--strip-components=1",
               "-C",
               extracted
             ])

    assert File.read!(Path.join(extracted, "bin/arm-gcc")) == "compiler"
    assert File.read_link!(Path.join(extracted, "bin/arm-cc")) == "arm-gcc"

    File.write!(Path.join(install, "bin/arm-gcc"), "different compiler")

    assert {message, 1} =
             System.cmd("bash", [script, install, output, toolchain, "linux_x86_64"],
               stderr_to_stdout: true
             )

    assert message =~ "Archive already exists"
    assert File.read!(Path.join(output, native)) == archive
    assert File.read!(Path.join(install, "bin/arm-gcc")) == "different compiler"

    assert {_, 0} = System.cmd("bash", [script, install, output, toolchain, "darwin_arm"])
    later_host = ToolchainMetadata.archive_name(toolchain, "darwin_arm")
    assert later_host == String.replace(native, "--x86_64-linux-gnu", "--aarch64-apple-darwin")
    assert File.read!(Path.join(output, native)) == archive
    assert Enum.sort(File.ls!(output)) == Enum.sort([native, later_host])
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
