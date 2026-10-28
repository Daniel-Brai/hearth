defmodule HearthWeb.Attachments do
  alias Hearth.Media
  alias HearthWeb.MediaJSON

  @spec load([map()] | map(), :post | :reply | :message) :: %{optional(String.t()) => [map()]}
  def load(items, owner) do
    ids = items |> List.wrap() |> Enum.map(& &1.id)

    owner
    |> Media.list_attachments(ids)
    |> Map.new(fn {id, attachments} ->
      {id, Enum.map(attachments, &MediaJSON.serialize(&1.media))}
    end)
  end
end
