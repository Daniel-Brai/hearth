defmodule HearthWeb.Schema.UpdateRoomBody do
  use JSV.Schema

  alias HearthWeb.Schema.RoomSettings

  defschema %{
    title: "UpdateRoomBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      name: string(minLength: 1, maxLength: 40),
      topic: nullable(string(maxLength: 200)),
      position: integer(minimum: 0),
      access: enum(~w[everyone roles]),
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
