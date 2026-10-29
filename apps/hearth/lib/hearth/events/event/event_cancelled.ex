defmodule Hearth.Events.EventCancelled do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[event_id community_id room_id cancelled_by_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          event_id: T.id(),
          community_id: T.id(),
          room_id: nil | T.id(),
          cancelled_by_id: T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "rooms:#{id}"
end
