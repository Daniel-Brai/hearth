defmodule HearthWeb.Schema.LevelBody do
  use JSV.Schema

  alias Hearth.Communities.Community
  alias HearthWeb.Schema

  defschema %{
    title: "LevelBody",
    type: :object,
    description: "For a room, null follows the community and it can't go above it",
    required: [:level],
    additionalProperties: false,
    properties: %{
      level: nullable(Schema.enum_of(Community, :moderation))
    }
  }
end
