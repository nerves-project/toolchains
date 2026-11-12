# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

Code.require_file("../metadata.exs", __DIR__)
ExUnit.start()

defmodule ToolchainMetadataTest do
  use ExUnit.Case

  @tag :tmp_dir
  test "packaging preserves the install tree and emits identical native and compatibility archives",
       %{tmp_dir: tmp_dir} do
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    app = "nerves_toolchain_armv7_nerves_linux_gnueabihf"
    install = Path.join(tmp_dir, "installed")
    output = Path.join(tmp_dir, "archives")
    File.mkdir_p!(Path.join(install, "bin"))
    File.write!(Path.join(install, "bin/arm-gcc"), "compiler")
    File.ln_s!("arm-gcc", Path.join(install, "bin/arm-cc"))

    script = Path.expand("../scripts/package.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, install, output, app, "linux_x86_64"])
    {native, compatibility} = ToolchainMetadata.archive_names(app, "linux_x86_64")
    assert File.read!(Path.join(output, native)) == File.read!(Path.join(output, compatibility))
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
  end
end
