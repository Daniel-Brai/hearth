defmodule Hearth.Common.Transform do
  alias Hearth.Common

  @spec atomize_string_keys(map()) :: map()
  def atomize_string_keys(map) when is_non_struct_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {Common.to_atom(key), atomize_value(value)}
      {key, value} -> {key, atomize_value(value)}
    end)
  end

  defp atomize_value(value) when is_non_struct_map(value), do: atomize_string_keys(value)
  defp atomize_value(value) when is_list(value), do: Enum.map(value, &atomize_value/1)
  defp atomize_value(value), do: value

  @spec remove_nil_fields(map() | keyword()) :: map() | keyword()
  def remove_nil_fields(value) when is_non_struct_map(value) do
    value
    |> do_remove_nil_fields()
    |> Map.new()
  end

  def remove_nil_fields(value) when is_list(value),
    do: value |> do_remove_nil_fields() |> Enum.reverse()

  defp do_remove_nil_fields(value) do
    Enum.reduce(value, [], fn
      {_key, nil}, acc ->
        acc

      {key, nested}, acc when is_non_struct_map(nested) ->
        [{key, remove_nil_fields(nested)} | acc]

      elem, acc ->
        [elem | acc]
    end)
  end
end
