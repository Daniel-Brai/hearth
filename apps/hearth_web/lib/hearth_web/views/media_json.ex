defmodule HearthWeb.MediaJSON do
  alias Hearth.Media
  alias HearthWeb.MediaJSON

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

  def unfurl(%{preview: preview}),
    do: Map.take(preview, ~w[url site title description image_url]a)

  def upload(%{media: media, upload: upload}),
    do: %{media: MediaJSON.serialize(media), upload: upload}

  def list_upload_parts(%{parts: parts}) do
    %{parts: Enum.map(parts, &Map.take(&1, ~w[number etag size]a))}
  end

  def sign_upload_parts(%{urls: urls}),
    do: %{urls: Map.new(urls, fn {number, url} -> {to_string(number), url} end)}

  def complete_upload(%{media: media}), do: MediaJSON.serialize(media)
end
