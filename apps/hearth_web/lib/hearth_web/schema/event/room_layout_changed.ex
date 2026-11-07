defmodule HearthWeb.Schema.Event.RoomLayoutChanged do
  use JSV.Schema

  defschema %{
    title: "RoomLayoutChanged",
    type: :object,
    description: "On rooms:<community id> when room groups or the order of rooms change",
    required: [:community_id],
    properties: %{community_id: uuid()}
  }

  @spec event() :: module()
  def event, do: Hearth.Communities.RoomLayoutChanged
end
