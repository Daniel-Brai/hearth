defmodule HearthWeb.Schema.Event.MessageRemoved do
  use JSV.Schema

  defschema %{
    title: "MessageRemoved",
    type: :object,
    description: "On room:<id> or conversation:<id>",
    required: ~w[message_id room_id conversation_id]a,
    properties: %{
      message_id: uuid(),
      room_id: nullable(uuid()),
      conversation_id: nullable(uuid())
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Chat.MessageRemoved
end
