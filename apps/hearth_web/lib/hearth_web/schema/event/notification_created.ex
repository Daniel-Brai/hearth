defmodule HearthWeb.Schema.Event.NotificationCreated do
  use JSV.Schema

  alias Hearth.Notifications.Notification
  alias HearthWeb.Schema

  defschema %{
    title: "NotificationCreated",
    type: :object,
    description: "On user:<id>",
    required: [:notification_id, :user_id, :kind],
    properties: %{
      notification_id: uuid(),
      user_id: uuid(),
      kind: Schema.enum_of(Notification, :kind)
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Notifications.NotificationCreated
end
