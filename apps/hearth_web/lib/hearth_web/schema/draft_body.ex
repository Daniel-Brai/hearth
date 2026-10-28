defmodule HearthWeb.Schema.DraftBody do
  use JSV.Schema

  defschema %{
    title: "DraftBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      title: nullable(string(maxLength: 150)),
      body: nullable(string(maxLength: 40_000)),
      kind_id: nullable(uuid())
    }
  }
end
