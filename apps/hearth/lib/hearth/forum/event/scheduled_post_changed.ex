defmodule Hearth.Forum.ScheduledPostChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields [:user_id, :scheduled_id]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{user_id: T.id(), scheduled_id: T.id()}

  # Goes only to the person who scheduled it to keep their other tabs in step
  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{user_id: id}), do: "user:#{id}"
end
