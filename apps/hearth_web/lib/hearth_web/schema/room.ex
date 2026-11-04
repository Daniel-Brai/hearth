defmodule HearthWeb.Schema.Room do
  use JSV.Schema

  alias Hearth.Communities
  alias HearthWeb.Schema
  alias HearthWeb.Schema.RoomSettings

  defschema %{
    title: "Room",
    type: :object,
    required:
      ~w[id community_id type slug name topic position moderation access settings archived_at]a,
    properties: %{
      id: uuid(),
      community_id: uuid(),
      type: Schema.enum_of(Communities.Room, :type),
      slug: string(),
      name: string(),
      topic: nullable(string()),
      position: integer(),
      moderation: nullable(Schema.enum_of(Communities.Room, :moderation)),
      access: Schema.enum_of(Communities.Room, :access),
      settings: RoomSettings,
      role_ids:
        array_of(uuid(), description: "Who can see a private room, for people with room.update"),
      archived_at: nullable(string(format: :"date-time"))
    }
  }
end
