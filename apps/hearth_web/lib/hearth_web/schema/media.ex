defmodule HearthWeb.Schema.Media do
  use JSV.Schema

  alias Hearth.Media.Asset
  alias HearthWeb.Schema
  alias HearthWeb.Schema.MediaUrls

  defschema %{
    title: "Media",
    type: :object,
    required: ~w[
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
      urls
    ]a,
    properties: %{
      id: uuid(),
      name: string(),
      purpose: Schema.enum_of(Asset, :purpose),
      content_type: string(),
      byte_size: pos_integer(),
      status: Schema.enum_of(Asset, :status),
      failure: nullable(string()),
      width: nullable(pos_integer()),
      height: nullable(pos_integer()),
      duration_ms: nullable(pos_integer()),
      blurhash: nullable(string()),
      urls: nullable(MediaUrls)
    }
  }
end
