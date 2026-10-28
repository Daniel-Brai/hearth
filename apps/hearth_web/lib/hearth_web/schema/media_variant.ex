defmodule HearthWeb.Schema.MediaVariant do
  use JSV.Schema

  defschema %{
    title: "MediaVariant",
    type: :object,
    required: ~w[width height format url]a,
    properties: %{
      width: pos_integer(),
      height: pos_integer(),
      format: enum(~w[webp avif mp4]),
      url: string()
    }
  }
end
