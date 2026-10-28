defmodule HearthWeb.Schema.Event.RoomChanged do
  use JSV.Schema

  defschema %{
    title: "RoomChanged",
    type: :object,
    description: "On community:<id>",
    required: [:community_id, :room_id],
    properties: %{
      community_id: uuid(),
      room_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Communities.RoomChanged
end
