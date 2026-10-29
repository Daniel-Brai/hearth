defmodule HearthWeb.Schema.SaveKindsBody do
  use JSV.Schema

  alias HearthWeb.Schema.KindInput

  defschema %{
    title: "SaveKindsBody",
    type: :object,
    required: [:kinds],
    additionalProperties: false,
    properties: %{kinds: array_of(KindInput, maxItems: 8)}
  }
end
