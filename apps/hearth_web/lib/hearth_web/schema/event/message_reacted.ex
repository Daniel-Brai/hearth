defmodule HearthWeb.Schema.Event.MessageReacted do
  use JSV.Schema

  defschema %{
    title: "MessageReacted",
    type: :object,
    description: "On room:<id> or conversation:<id>, with the emoji's new count",
    required: ~w[message_id room_id conversation_id user_id emoji on count]a,
    properties: %{
      message_id: uuid(),
      room_id: nullable(uuid()),
      conversation_id: nullable(uuid()),
      user_id: uuid(),
      emoji: string(),
      on: boolean(description: "Added rather than taken back"),
      count: non_neg_integer()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Chat.MessageReacted
end
