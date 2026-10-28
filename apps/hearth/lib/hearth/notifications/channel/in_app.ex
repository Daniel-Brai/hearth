defmodule Hearth.Notifications.Channel.InApp do
  @behaviour Hearth.Notifications.Channel

  alias Hearth.Accounts.User
  alias Hearth.Notifications
  alias Hearth.Notifications.InAppMessage
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.NotificationCreated

  @impl Hearth.Notifications.Channel
  def name, do: :in_app

  @impl Hearth.Notifications.Channel
  def send(%module{} = message, %User{id: user_id} = user) do
    %InAppMessage{} = in_app = module.to_in_app(message, user)

    params = Map.from_struct(in_app)

    with {:ok, notification} <- Notification.insert(%Notification{user_id: user_id}, params) do
      Notifications.broadcast_to_pubsub(%NotificationCreated{
        notification_id: notification.id,
        user_id: user_id,
        kind: notification.kind
      })
    end
  end

  def send(_message, _notifiable), do: :ok
end
