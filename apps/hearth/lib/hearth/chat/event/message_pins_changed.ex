defmodule Hearth.Chat.MessagePinsChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields [:room_id]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{room_id: T.id()}

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{room_id: id}), do: "room:#{id}"
end
