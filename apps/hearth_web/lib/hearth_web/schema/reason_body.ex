defmodule HearthWeb.Schema.ReasonBody do
  use JSV.Schema

  defschema %{
    title: "ReasonBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      reason: nullable(string(maxLength: 500))
    }
  }
end
