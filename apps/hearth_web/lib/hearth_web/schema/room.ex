defmodule HearthWeb.Schema.Room do
  use JSV.Schema

  defschema %{
    title: "Room",
    type: :object,
    required:
      ~w[id community_id type slug name topic position moderation access settings archived_at]a,
    properties: %{
      id: uuid(),
      community_id: uuid(),
      type: enum(~w[text voice]),
      slug: string(),
      name: string(),
      topic: nullable(string()),
      position: integer(),
      moderation: nullable(enum(~w[full reports none])),
      access: enum(~w[everyone roles]),
      settings: HearthWeb.Schema.RoomSettings,
      role_ids:
        array_of(uuid(), description: "Who can see a private room, for people with room.update"),
      archived_at: nullable(string(format: :"date-time"))
    }
  }
end
