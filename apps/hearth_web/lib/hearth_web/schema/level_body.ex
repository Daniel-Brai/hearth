defmodule HearthWeb.Schema.LevelBody do
  use JSV.Schema

  defschema %{
    title: "LevelBody",
    type: :object,
    description: "For a room, null follows the community and it can't go above it",
    required: [:level],
    additionalProperties: false,
    properties: %{
      level: nullable(enum(~w[full reports none]))
    }
  }
end
