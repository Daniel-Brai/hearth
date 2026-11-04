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

  # Scheduled items hold ids until they go out, so their files are looked up by id
  @spec media_for([map()] | map()) :: %{optional(String.t()) => map()}
  def media_for(items) do
    items
    |> List.wrap()
    |> Enum.flat_map(& &1.attachment_ids)
    |> Media.get_images()
  end

  # A file deleted while it waited is left out here and fails the send
  @spec pick([String.t()], map()) :: [map()]
  def pick(ids, media) do
    ids
    |> Enum.map(&media[&1])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&MediaJSON.serialize/1)
  end
end
