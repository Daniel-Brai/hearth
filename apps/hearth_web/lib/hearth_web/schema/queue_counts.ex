defmodule HearthWeb.Schema.QueueCounts do
  use JSV.Schema

  defschema %{
    title: "QueueCounts",
    type: :object,
    description: "By community id",
    required: [:counts],
    properties: %{
      counts: %{type: :object, additionalProperties: %{type: :integer, minimum: 0}}
    }
  }
end
