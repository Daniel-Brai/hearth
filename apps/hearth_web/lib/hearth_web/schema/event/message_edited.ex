defmodule HearthWeb.Schema.Event.MessageEdited do
  use JSV.Schema

  defschema %{
    title: "MessageEdited",
    type: :object,
    description: "On room:<id> or conversation:<id>, fetch it again for the new text",
    required: ~w[message_id room_id conversation_id]a,
    properties: %{
      message_id: uuid(),
      room_id: nullable(uuid()),
      conversation_id: nullable(uuid())
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Chat.MessageEdited
end
