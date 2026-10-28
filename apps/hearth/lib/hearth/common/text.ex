defmodule Hearth.Common.Text do
  @username_chars ~c"abcdefghijklmnopqrstuvwxyz0123456789_"

  @spec normalize(String.t()) :: String.t()
  def normalize(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  @spec valid_username?(term()) :: boolean()
  def valid_username?(value) when is_binary(value) and byte_size(value) in 3..20 do
    value
    |> String.to_charlist()
    |> Enum.all?(&(&1 in @username_chars))
  end

  def valid_username?(_value), do: false

  @doc """
  Text cut to max_length characters at a nearby word boundary ending in …

      iex> Hearth.Common.Text.truncate("Keep the state in the DOM, not on the controller", 24)
      "Keep the state in the…"
  """
  @spec truncate(String.t(), pos_integer()) :: String.t()
  def truncate(text, max_length)
      when is_binary(text) and is_integer(max_length) and max_length > 1 do
    case String.length(text) <= max_length do
      true -> text
      false -> shorten(text, max_length)
    end
  end

  defp shorten(text, max_length) do
    cut = String.slice(text, 0, max_length - 1)

    kept =
      case last_space(cut) do
        nil -> cut
        at when at >= div(max_length, 2) -> String.slice(cut, 0, at)
        _too_early -> cut
      end

    kept
    |> String.trim_trailing()
    |> String.trim_trailing(",")
    |> Kernel.<>("…")
  end

  defp last_space(text) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(nil, fn
      {" ", at}, _last -> at
      _grapheme, last -> last
    end)
  end
end
