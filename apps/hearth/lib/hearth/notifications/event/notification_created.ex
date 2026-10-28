defmodule Hearth.Notifications.NotificationCreated do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[notification_id user_id kind]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{notification_id: T.id(), user_id: T.id(), kind: atom()}

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{user_id: id}), do: "user:#{id}"
end
