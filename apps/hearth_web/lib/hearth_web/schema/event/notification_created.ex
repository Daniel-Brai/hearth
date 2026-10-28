defmodule HearthWeb.Schema.Event.NotificationCreated do
  use JSV.Schema

  defschema %{
    title: "NotificationCreated",
    type: :object,
    description: "On user:<id>",
    required: [:notification_id, :user_id, :kind],
    properties: %{
      notification_id: uuid(),
      user_id: uuid(),
      kind: enum(~w[reply mention dm answer event_scheduled event_reminder live_started invite
             transcript_ready])
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Notifications.NotificationCreated
end
