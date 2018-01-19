defmodule Nerves.Toolchain.CTNG do
  use Nerves.Package.Platform

  alias Nerves.Artifact
  import Mix.Nerves.Utils

  def bootstrap(_pkg) do
    :ok
  end

  def build(pkg, _toolchain, _opts) do
    build_path = Artifact.build_path(pkg)
    File.mkdir_p!(build_path)
    script = 
      :nerves_toolchain_ctng
      |> Nerves.Env.package()
      |> Map.get(:path)
      |> Path.join("build.sh")

    defconfig = defconfig(pkg)

    case shell(script, [defconfig, build_path]) do
      {_, 0} -> 
        x_tools = Path.join(build_path, "x-tools")
        tuple = 
          x_tools
          |> File.ls!
          |> List.first
        toolchain_path = Path.join(x_tools, tuple)
        {:ok, toolchain_path}
      {error, _} -> {:error, error}
    end
  end

  def archive(pkg, _toolchain, _opts) do
    build_path = Artifact.build_path(pkg)
    
    script = 
      :nerves_toolchain_ctng
      |> Nerves.Env.package()
      |> Map.get(:path)
      |> Path.join("scripts")
      |> Path.join("archive.sh")
    
    tar_path = Path.join([build_path, Artifact.name(pkg) <> Artifact.ext(pkg)])

    case shell(script, [build_path, tar_path]) do
      {_, 0} -> {:ok, tar_path}
      {error, _} -> {:error, error}
    end
  end

  def clean(pkg) do
    pkg
    |> Artifact.dir()
    |> File.rm_rf()
  end

  defp defconfig(pkg) do
    pkg.config
    |> Keyword.get(:platform_config)
    |> Keyword.get(:defconfig)
    |> Path.expand
  end
  
end
