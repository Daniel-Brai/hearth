defmodule HearthWeb.Schema.Room do
  use JSV.Schema

  defschema %{
    title: "Room",
    type: :object,
    required: ~w[id community_id type slug name topic position moderation archived_at]a,
    properties: %{
      id: uuid(),
      community_id: uuid(),
      type: enum(~w[text voice]),
      slug: string(),
      name: string(),
      topic: nullable(string()),
      position: integer(),
      moderation: nullable(enum(~w[full reports none])),
      archived_at: nullable(string(format: :"date-time"))
    }
  }
end
