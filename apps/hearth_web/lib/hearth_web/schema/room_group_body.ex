defmodule HearthWeb.Schema.RoomGroupBody do
  use JSV.Schema

  defschema %{
    title: "RoomGroupBody",
    type: :object,
    required: [:name],
    additionalProperties: false,
    properties: %{name: string(minLength: 1, maxLength: 40)}
  }
end
