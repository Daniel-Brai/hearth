defmodule Hearth.Instance.Release do
  @fields ~w[version name url notes published_at]a

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          version: String.t(),
          name: String.t(),
          url: String.t(),
          notes: nil | String.t(),
          published_at: nil | DateTime.t()
        }

  @spec from!(map()) :: no_return() | t()
  def from!(%{} = data) do
    %{
      "tag_name" => tag,
      "name" => name,
      "html_url" => url,
      "body" => notes,
      "published_at" => published_at
    } = data

    %__MODULE__{
      version: String.trim_leading(tag, "v"),
      name: name || tag,
      url: url,
      notes: notes,
      published_at: timestamp!(published_at)
    }
  end

  # GitHub sends whole seconds, and Hearth keeps microseconds
  defp timestamp!(nil), do: nil

  defp timestamp!(value) do
    {:ok, %DateTime{microsecond: {microsecond, _precision}} = at, _offset} =
      DateTime.from_iso8601(value)

    %{at | microsecond: {microsecond, 6}}
  end
end
