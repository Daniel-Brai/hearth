defmodule Hearth.Events.EventUpdated do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[event_id community_id room_id moved]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          event_id: T.id(),
          community_id: T.id(),
          room_id: nil | T.id(),
          moved: boolean()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "rooms:#{id}"
end
