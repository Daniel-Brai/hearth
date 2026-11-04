defmodule Hearth.Chat.ScheduledMessageChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields [:user_id, :scheduled_id]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{user_id: T.id(), scheduled_id: T.id()}

  # Only the person who scheduled it hears about it, so their other tabs stay in step
  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{user_id: id}), do: "user:#{id}"
end
