defmodule HearthWeb.Schema.UpdateRoomBody do
  use JSV.Schema

  alias Hearth.Communities.Room
  alias HearthWeb.Schema
  alias HearthWeb.Schema.RoomSettings

  defschema %{
    title: "UpdateRoomBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      name: string(minLength: 1, maxLength: 40),
      topic: nullable(string(maxLength: 200)),
      group_id: nullable(uuid(description: "Null for no group. Without a position it goes last")),
      position: integer(minimum: 0),
      access: Schema.enum_of(Room, :access),
      role_ids: array_of(uuid()),
      settings: %{
        type: :object,
        description: "Only the choices sent change",
        additionalProperties: false,
        properties: RoomSettings.json_schema().properties
      }
    }
  }
end
