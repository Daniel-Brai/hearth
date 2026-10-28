defmodule HearthWeb.MediaJSON do
  alias Hearth.Media

  @fields ~w[
    id
    name
    purpose
    content_type
    byte_size
    status
    failure
    width
    height
    duration_ms
    blurhash
  ]a

  def show(%{media: media}), do: serialize(media)

  @spec serialize(map()) :: map()
  def serialize(media) do
    media
    |> Map.take(@fields)
    |> Map.put(:urls, Media.urls(media))
  end
end
