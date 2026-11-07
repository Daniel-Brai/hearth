defmodule HearthWeb.Schema.CreateRoomBody do
  use JSV.Schema

  alias Hearth.Communities.Room
  alias HearthWeb.Schema

  defschema %{
    title: "CreateRoomBody",
    type: :object,
    required: [:name],
    additionalProperties: false,
    properties: %{
      name: string(minLength: 1, maxLength: 40),
      type: Schema.enum_of(Room, :type),
      topic: nullable(string(maxLength: 200)),
      group_id: nullable(uuid(description: "Null for no group. Without a position it goes last")),
      position: integer(minimum: 0),
      access: Schema.enum_of(Room, :access),
      role_ids: array_of(uuid())
    }
  }
end
