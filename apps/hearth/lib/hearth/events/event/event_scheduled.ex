defmodule Hearth.Events.EventScheduled do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[event_id community_id host_id notify]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          event_id: T.id(),
          community_id: T.id(),
          host_id: T.id(),
          notify: boolean()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "community:#{id}"

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_with(%__MODULE__{} = event),
    do: Map.take(event, ~w[event_id community_id host_id]a)
end
