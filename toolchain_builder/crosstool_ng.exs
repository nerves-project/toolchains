# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

defmodule CrosstoolNG do
  @root __DIR__

  def config do
    {config, _} = Code.eval_file(Path.join(@root, "config.exs"))
    config
  end

  def identity do
    files =
      [__ENV__.file, Path.join(@root, "scripts/apply-patches.sh")] ++
        Path.wildcard(Path.join(@root, "patches/crosstool-ng/*"))

    checksum =
      files
      |> Enum.sort()
      |> Enum.map(&[Path.relative_to(&1, @root), File.read!(&1)])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> String.slice(0, 16)

    "#{config().ctng_tag}-#{checksum}"
  end

  def ensure! do
    install = Path.join([System.user_home!(), ".nerves", "ct-ng", identity()])
    ctng = Path.join(install, "bin/ct-ng")

    unless File.regular?(ctng) do
      build!(install)
    end

    ctng
  end

  defp build!(install) do
    tag = config().ctng_tag
    work = Path.join(System.tmp_dir!(), "toolchain-ctng-#{System.unique_integer([:positive])}")
    source = Path.join(work, "source")
    File.mkdir_p!(work)

    try do
      run!("git", ["clone", "https://github.com/crosstool-ng/crosstool-ng.git", source])
      run!("git", ["checkout", tag], cd: source)

      run!("bash", [
        Path.join(@root, "scripts/apply-patches.sh"),
        source,
        Path.join(@root, "patches/crosstool-ng")
      ])

      run!("bash", ["./bootstrap"], cd: source)
      {env, make} = build_environment()
      run!("bash", ["./configure", "--prefix=#{install}"], cd: source, env: env)
      run!(make, [], cd: source, env: env)
      run!(make, ["install"], cd: source, env: env)
    after
      File.rm_rf!(work)
    end
  end

  defp build_environment do
    case :os.type() do
      {:unix, :darwin} ->
        brew = output!("brew", ["--prefix"])
        binutils = output!("brew", ["--prefix", "binutils"])
        ncurses = output!("brew", ["--prefix", "ncurses"])
        gcc = "15"

        env = [
          {"CC", "gcc-#{gcc}"},
          {"CXX", "g++-#{gcc}"},
          {"AR", "gcc-ar-#{gcc}"},
          {"NM", "gcc-nm-#{gcc}"},
          {"RANLIB", "gcc-ranlib-#{gcc}"},
          {"CPP", "cpp-#{gcc}"},
          {"OBJDUMP", Path.join(binutils, "bin/gobjdump")},
          {"OBJCOPY", Path.join(binutils, "bin/gobjcopy")},
          {"READELF", Path.join(binutils, "bin/greadelf")},
          {"CFLAGS", "-I#{brew}/include -I#{ncurses}/include"},
          {"LDFLAGS", "-L#{brew}/lib -lintl"},
          {"SED", Path.join(brew, "bin/gsed")},
          {"MAKE", Path.join(brew, "bin/gmake")}
        ]

        {env, Path.join(brew, "bin/gmake")}

      {:unix, :freebsd} ->
        {[
           {"SED", "/usr/local/bin/gsed"},
           {"MAKE", "/usr/local/bin/gmake"},
           {"PATCH", "/usr/local/bin/gpatch"}
         ], "/usr/local/bin/gmake"}

      _ ->
        {[{"SED", "sed"}], "make"}
    end
  end

  defp output!(command, args), do: run!(command, args) |> String.trim()

  defp run!(command, args, opts \\ []) do
    {output, status} = System.cmd(command, args, Keyword.put(opts, :stderr_to_stdout, true))
    if status != 0, do: raise("#{command} failed:\n#{output}")
    output
  end
end
