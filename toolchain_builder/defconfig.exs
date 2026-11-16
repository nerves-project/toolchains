# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

defmodule ToolchainDefconfig do
  def read!(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      cond do
        match = Regex.run(~r/^(CT_[A-Z0-9_]+)=(.*)$/, line) ->
          [_, key, value] = match
          [{key, value}]

        match = Regex.run(~r/^# (CT_[A-Z0-9_]+) is not set$/, line) ->
          [_, key] = match
          [{key, "n"}]

        true ->
          []
      end
    end)
    |> Map.new()
  end

  def validate!(target, resolved) do
    expected = read!(target)
    actual = read!(resolved)

    mismatches =
      expected
      |> Enum.sort()
      |> Enum.flat_map(fn {key, value} ->
        if Map.get(actual, key) == value do
          []
        else
          ["#{key}: requested #{value}, resolved #{Map.get(actual, key, "<missing>")}"]
        end
      end)

    if mismatches != [] do
      raise "crosstool-NG changed explicit configuration:\n" <> Enum.join(mismatches, "\n")
    end

    :ok
  end
end
