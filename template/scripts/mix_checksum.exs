#!/usr/bin/env elixir

defmodule MixChecksum do
  @moduledoc """
  Compute a short checksum from a Mix project's :nerves_project checksum files.
  """

  @short_len 7

  @doc """
  Script entrypoint.
  """
  @spec main([String.t()]) :: no_return()
  def main(argv) do
    case argv do
      [mix_file] ->
        checksum =
          mix_file
          |> Path.expand()
          |> checksum_from_mix_file()

        IO.puts(checksum)
        System.halt(0)

      _ ->
        IO.puts(:stderr, "Usage: mix_checksum.exs <path/to/mix.exs>")
        System.halt(1)
    end
  rescue
    error in RuntimeError ->
      IO.puts(:stderr, error.message)
      System.halt(1)
  end

  @doc """
  Load a mix.exs, call project/0 on its main module, and compute the short checksum.
  """
  @spec checksum_from_mix_file(String.t()) :: String.t()
  def checksum_from_mix_file(mix_file) do
    if !File.regular?(mix_file) do
      raise("mix.exs not found: #{mix_file}")
    end

    project_module = load_project_module(mix_file)
    project = project_module.project()

    nerves_project =
      cond do
        Keyword.has_key?(project, :nerves_project) ->
          value = Keyword.fetch!(project, :nerves_project)

          if is_list(value) do
            value
          else
            raise(":nerves_project must be a keyword list")
          end

        Keyword.has_key?(project, :nerves_package) ->
          value = Keyword.fetch!(project, :nerves_package)

          if is_list(value) do
            value
          else
            raise(":nerves_package must be a keyword list")
          end

        true ->
          raise("missing :nerves_project key in project/0 config")
      end

    checksum_paths =
      case Keyword.get(nerves_project, :checksum) do
        nil -> []
        value when is_list(value) -> value
        _ -> raise(":nerves_project :checksum must be a list")
      end

    base_dir = Path.dirname(mix_file)

    blob =
      checksum_paths
      |> expand_paths(base_dir)
      |> Enum.map(&File.read!/1)
      |> Enum.map(&:crypto.hash(:sha256, &1))

    checksum =
      :crypto.hash(:sha256, blob)
      |> Base.encode16()

    {checksum_short, _} = String.split_at(checksum, @short_len)
    checksum_short
  end

  @doc """
  Load mix.exs and find the project module that exports project/0.
  """
  @spec load_project_module(String.t()) :: module()
  def load_project_module(mix_file) do
    _ = Application.ensure_all_started(:mix)

    modules =
      mix_file
      |> Code.compile_file()
      |> Enum.map(fn {module, _bytecode} -> module end)

    Enum.find(modules, fn module ->
      function_exported?(module, :project, 0) and String.ends_with?(Atom.to_string(module), ".MixProject")
    end) ||
      Enum.find(modules, fn module -> function_exported?(module, :project, 0) end) ||
      raise("could not find a module exporting project/0 in #{mix_file}")
  end

  @doc """
  Expand file, wildcard, and directory entries into unique regular files.
  """
  @spec expand_paths([String.t()], String.t()) :: [String.t()]
  def expand_paths(paths, dir) do
    paths
    |> Enum.map(&Path.join(dir, &1))
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.flat_map(&dir_files/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.filter(&File.regular?/1)
    |> Enum.uniq()
  end

  @spec dir_files(String.t()) :: [String.t()]
  defp dir_files(path) do
    if File.dir?(path) do
      Path.wildcard(Path.join(path, "**"))
    else
      [path]
    end
  end
end

MixChecksum.main(System.argv())
