defmodule HearthWeb.Schema.Event.SoundPlayed do
  use JSV.Schema

  defschema %{
    title: "SoundPlayed",
    type: :object,
    description: "On room:<id>, for everyone in the room to hear",
    required: ~w[message_id room_id author_id sound]a,
    properties: %{
      message_id: uuid(),
      room_id: uuid(),
      author_id: uuid(),
      sound: string()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Chat.SoundPlayed
end
