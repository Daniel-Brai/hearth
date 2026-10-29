defmodule Hearth.Chat.RoomActivity do
  # Tells the community a room has something new for its unread count, without who or what

  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields [:room_id, :community_id]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{room_id: T.id(), community_id: T.id()}

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "rooms:#{id}"
end
