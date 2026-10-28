defmodule Hearth.Chat.MessageReacted do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[message_id room_id conversation_id user_id emoji on count]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          message_id: T.id(),
          room_id: nil | T.id(),
          conversation_id: nil | T.id(),
          user_id: T.id(),
          emoji: String.t(),
          on: boolean(),
          count: non_neg_integer()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{room_id: nil, conversation_id: id}), do: "conversation:#{id}"
  def broadcast_on(%__MODULE__{room_id: id}), do: "room:#{id}"
end
