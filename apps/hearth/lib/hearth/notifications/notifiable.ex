defprotocol Hearth.Notifications.Notifiable do
  # :mail gets a {name, email} and :web_push gets the push subscriptions
  @spec recipients(t(), atom()) :: term()
  def recipients(notifiable, channel)
end

defimpl Hearth.Notifications.Notifiable, for: Hearth.Accounts.User do
  alias Hearth.Accounts
  alias Hearth.Notifications.PushSubscription

  def recipients(user, :mail), do: {Accounts.display_name(user), user.email}
  def recipients(user, :web_push), do: PushSubscription.all(user_id: user.id)
end
