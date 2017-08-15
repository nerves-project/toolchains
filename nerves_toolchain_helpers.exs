defmodule Nerves.Toolchain do
  @doc """
  Returns the architecture for the host system.

  ## Example return values
    "x86_64"
    "arm"
  """
  @spec host_arch() :: String.t
  def host_arch() do
    :erlang.system_info(:system_architecture)
    |> to_string
    |> parse_arch
  end

  @doc false
  def parse_arch(arch) when is_binary(arch) do
    arch
    |> String.split("-")
    |> parse_arch
  end
  @doc false
  def parse_arch(arch) when is_list(arch) do
    arch = List.first(arch)
    case arch do
      <<"win", _tail :: binary>> -> "x86_64"
      arch ->
        if String.contains?(arch, "arm") do
          "arm"
        else
          "x86_64"
        end
    end
  end

  @doc """
  Returns the platform for the host system.

  ## Example return values
    "win"
    "linux"
    "darwin"
  """
  @spec host_platform() :: String.t
  def host_platform() do
    :erlang.system_info(:system_architecture)
    |> to_string
    |> parse_platform
  end
  @doc false
  def parse_platform(platform) when is_binary(platform) do
    platform
    |> String.split("-")
    |> parse_platform
  end
  @doc false
  def parse_platform(platform) when is_list(platform) do
    case platform do
      [<<"win", _tail :: binary>> | _] ->
        "win"
      [_ , _, "linux" | _] ->
        "linux"
      [_, _, <<"darwin", _tail :: binary>> | _] ->
        "darwin"
      _ ->
        Mix.raise "Could not determine your host platform from system: #{platform}"
    end
  end
end


# Instead of duplicating this file in each toolchain, copy it to the toolchain
#  directory. This is primarily used for including a copy when packaging it
#  for hex.
defmodule Mix.Tasks.Copy.Toolchain.Helpers do
  @moduledoc false

  # Copy this file into the toolchain so it can be shipped to hex.
  def run(_argv) do
    from = __ENV__.file
    filename = Path.basename(from)
    to = Path.join(File.cwd!, filename)
    File.cp!(from, to)
  end
end
