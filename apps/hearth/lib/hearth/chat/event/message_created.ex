defmodule Hearth.Chat.MessageCreated do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[message_id room_id conversation_id author_id reply_to_id reply_to_author_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          message_id: T.id(),
          room_id: nil | T.id(),
          conversation_id: nil | T.id(),
          author_id: T.id(),
          reply_to_id: nil | T.id(),
          reply_to_author_id: nil | T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{room_id: nil, conversation_id: id}), do: "conversation:#{id}"
  def broadcast_on(%__MODULE__{room_id: id}), do: "room:#{id}"
end
