defmodule HearthWeb.Schema.CreateRoomBody do
  use JSV.Schema

  defschema %{
    title: "CreateRoomBody",
    type: :object,
    required: [:name],
    additionalProperties: false,
    properties: %{
      name: string(minLength: 1, maxLength: 40),
      type: enum(~w[text voice]),
      topic: nullable(string(maxLength: 200)),
      position: integer(minimum: 0)
    }
  }
end
