defmodule HearthWeb.Schema.Event.RoomActivity do
  use JSV.Schema

  defschema %{
    title: "RoomActivity",
    type: :object,
    description: "On community:<id> when a room gets a message, for unread counts",
    required: [:room_id, :community_id],
    properties: %{room_id: uuid(), community_id: uuid()}
  }

  @spec event() :: module()
  def event, do: Hearth.Chat.RoomActivity
end
