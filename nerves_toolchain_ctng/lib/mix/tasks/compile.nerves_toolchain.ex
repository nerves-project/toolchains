# defmodule Mix.Tasks.Compile.NervesToolchain do
#   use Mix.Task
#   import Mix.NervesToolchain.Utils
#   require Logger
#
#   @moduledoc """
#   Build Nerves Toolchain
#   """
#
#   @recursive true
#   @dir "nerves/toolchain"
#   @artifacts "https://s3.amazonaws.com/nerves/artifacts/"
#
#   def run(_args) do
#     if System.get_env("NERVES_TOOLCHAIN") == nil do
#       build
#     end
#   end
#
#   def build() do
#     Env.initialize
#     Mix.shell.info "[nerves_toolchain][compile]"
#     project_config = Mix.Project.config
#     app = project_config[:app]
#     {:ok, _} = Application.ensure_all_started(toolchain)
#
#     config = Application.get_env(app, :nerves_env)
#
#     target_tuple = config[:target_tuple] ||
#       raise "Target tuple required to be set in toolchain env"
#
#     build_path  = Mix.Project.build_path
#                   |> Path.join(@dir)
#     params      = %{target_tuple: target_tuple, version: config[:version], build_path: build_path}
#
#     if stale?(build_path) do
#       File.rm_rf!(build_path)
#       toolchain   = http(cache, params)
#       toolchain
#       |> copy_build(params)
#     else
#       shell_info "Toolchain up to date"
#     end
#
#   end
#
#   defp stale?(build_path) do
#     manifest = Path.join(build_path, ".nerves.lock")
#     if (File.exists?(manifest)) do
#       src =  Path.join(File.cwd!, "src")
#       sources = src
#       |> File.ls!
#       |> Enum.map(& Path.join(src, &1))
#
#       Mix.Utils.stale?(sources, [manifest])
#     else
#       true
#     end
#   end
#
#   defp http(:github, params) do
#     shell_info "Downloading Toolchain"
#
#     url = "https://github.com/nerves-project/nerves-toolchain/releases/download/v#{params.version}/nerves-#{params.target_tuple}-#{host_platform}-#{host_arch}-v#{params.version}.tar.xz"
#     case Mix.Utils.read_path(url) do
#       {:ok, body} ->
#         shell_info "Toolchain Downloaded"
#         body
#       {_, error} ->
#         raise "Nerves Toolchain Github cache returned error: #{inspect error}"
#     end
#   end
#
#   defp cache(:none, params) do
#     compile(params)
#   end
#
#   defp compile(params) do
#     Mix.shell.info "Starting Nerves Toolchain Build"
#     Mix.shell.info "  Host Platform: #{host_platform}"
#     Mix.shell.info "  Host Arch: #{host_arch}"
#     Mix.shell.info "  Target Tuple: #{params[:target_tuple]}"
#
#     nerves_toolchain = Mix.Dep.loaded([])
#     |> Enum.find(fn
#       %{app: :nerves_toolchain} -> true
#       _ -> false
#     end)
#
#     toolchain_src = nerves_toolchain
#     |> Map.get(:opts)
#     |> Keyword.get(:dest)
#     ctng_config = File.cwd! <> "/#{host_platform}_defconfig"
#
#     result = System.cmd("sh", ["build.sh", ctng_config], stderr_to_stdout: true, cd: toolchain_src, into: IO.stream(:stdio, :line))
#     case result do
#       {_, 0} -> File.read!(toolchain_src <> "/toolchain.tar.xz")
#       {error, _} -> raise "Error compiling toolchain: #{inspect error}"
#     end
#   end
#
#   defp copy_build(toolchain_tar, params) do
#     shell_info "Unpacking Toolchain"
#     dest = params.build_path
#     tmp_dir = Path.join(dest, ".tmp")
#     File.mkdir_p(dest)
#     File.mkdir_p(tmp_dir)
#
#     tar_file = tmp_dir <> "/toolchain.tar.xz"
#     File.write(tar_file, toolchain_tar)
#     System.cmd("tar", ["xf", tar_file], cd: tmp_dir)
#
#     source =
#       File.ls!(tmp_dir)
#       |> Enum.map(& Path.join(tmp_dir, &1))
#       |> Enum.find(&File.dir?/1)
#
#     File.cp_r(source, dest)
#     File.rm_rf!(tmp_dir)
#     Path.join(dest, ".nerves.lock")
#     |> File.touch
#   end
#
#   def shell_info(text), do: Mix.shell.info "[nerves_toolchain][http] #{text}"
#
# end
