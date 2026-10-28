defmodule HearthWeb.Schema.EditSegmentBody do
  use JSV.Schema

  defschema %{
    title: "EditSegmentBody",
    type: :object,
    required: [:text],
    additionalProperties: false,
    properties: %{text: string(minLength: 1, maxLength: 5_000)}
  }
end
