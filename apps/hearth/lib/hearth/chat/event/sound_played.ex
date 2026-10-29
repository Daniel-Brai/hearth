defmodule Hearth.Chat.SoundPlayed do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[message_id room_id author_id sound]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          message_id: T.id(),
          room_id: T.id(),
          author_id: T.id(),
          sound: String.t()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{room_id: id}), do: "room:#{id}"
end
