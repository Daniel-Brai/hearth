defmodule HearthWeb.Schema.ModerationLevel do
  use JSV.Schema

  alias Hearth.Communities.Community
  alias HearthWeb.Schema

  defschema %{
    title: "ModerationLevel",
    type: :object,
    description: "Level is null when a room follows its community, effective is what applies",
    required: [:level, :effective],
    properties: %{
      level: nullable(Schema.enum_of(Community, :moderation)),
      effective: Schema.enum_of(Community, :moderation)
    }
  }
end
