defmodule HearthWeb.Schema.HandBody do
  use JSV.Schema

  defschema %{
    title: "HandBody",
    type: :object,
    required: [:raised],
    additionalProperties: false,
    properties: %{raised: boolean()}
  }
end
