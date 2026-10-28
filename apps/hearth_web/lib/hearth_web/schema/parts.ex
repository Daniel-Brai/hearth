defmodule HearthWeb.Schema.Parts do
  use JSV.Schema

  defschema %{
    title: "Parts",
    type: :object,
    required: [:parts],
    properties: %{
      parts:
        array_of(%{
          type: :object,
          required: [:number, :etag, :size],
          properties: %{number: pos_integer(), etag: string(), size: non_neg_integer()}
        })
    }
  }
end
