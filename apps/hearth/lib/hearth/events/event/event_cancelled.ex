defmodule Hearth.Events.EventCancelled do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[event_id community_id cancelled_by_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          event_id: T.id(),
          community_id: T.id(),
          cancelled_by_id: T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "community:#{id}"
end
