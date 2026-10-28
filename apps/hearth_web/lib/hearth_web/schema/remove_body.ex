defmodule HearthWeb.Schema.RemoveBody do
  use JSV.Schema

  defschema %{
    title: "RemoveBody",
    type: :object,
    required: [:reason],
    additionalProperties: false,
    properties: %{
      reason: string(minLength: 1, maxLength: 500)
    }
  }
end
