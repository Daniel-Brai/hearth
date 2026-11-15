defmodule HearthWeb.Schema.Event.MessagePinsChanged do
  use JSV.Schema

  defschema %{
    title: "MessagePinsChanged",
    type: :object,
    description: "On room:<id> when a message is pinned or unpinned there",
    required: [:room_id],
    properties: %{room_id: uuid()}
  }

  @spec event() :: module()
  def event, do: Hearth.Chat.MessagePinsChanged
end
