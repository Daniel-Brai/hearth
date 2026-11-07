defmodule HearthWeb.Schema.RoomLayoutBody do
  use JSV.Schema

  defschema %{
    title: "RoomLayoutBody",
    type: :object,
    required: [:groups, :room_ids],
    additionalProperties: false,
    properties: %{
      groups:
        array_of(
          %{
            type: :object,
            required: [:id, :room_ids],
            additionalProperties: false,
            properties: %{id: uuid(), room_ids: array_of(uuid())}
          },
          description: "Every group in order, each with its rooms in order"
        ),
      room_ids: array_of(uuid(), description: "The rooms in no group, in order")
    }
  }
end
