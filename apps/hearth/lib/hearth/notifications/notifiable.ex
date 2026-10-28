defprotocol Hearth.Notifications.Notifiable do
  # :mail gets a {name, email} and :web_push the push subscriptions
  @spec recipients(t(), atom()) :: term()
  def recipients(notifiable, channel)
end

defimpl Hearth.Notifications.Notifiable, for: Hearth.Accounts.User do
  alias Hearth.Notifications.PushSubscription

  def recipients(user, :mail), do: {user.display_name || user.username, user.email}
  def recipients(user, :web_push), do: PushSubscription.all(user_id: user.id)
end
