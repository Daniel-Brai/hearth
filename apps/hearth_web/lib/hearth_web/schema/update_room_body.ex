defmodule HearthWeb.Schema.UpdateRoomBody do
  use JSV.Schema

  defschema %{
    title: "UpdateRoomBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      name: string(minLength: 1, maxLength: 40),
      topic: nullable(string(maxLength: 200)),
      position: integer(minimum: 0)
    }
  }
end
