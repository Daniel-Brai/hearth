defmodule HearthWeb.Schema.DecisionBody do
  use JSV.Schema

  defschema %{
    title: "DecisionBody",
    type: :object,
    required: [:decision],
    additionalProperties: false,
    properties: %{decision: enum(~w[approved declined])}
  }
end
