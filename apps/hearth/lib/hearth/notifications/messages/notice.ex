defmodule Hearth.Notifications.Notice do
  use Hearth.Notifications.Message

  alias Hearth.Accounts.User
  alias Hearth.Notifications.InAppMessage
  alias Hearth.Notifications.WebPushMessage

  @enforce_keys ~w[in_app title body url]a
  defstruct ~w[in_app title body url setting]a

  @type t :: %__MODULE__{
          in_app: InAppMessage.t(),
          title: String.t(),
          body: String.t(),
          url: String.t(),
          setting: nil | String.t()
        }

  @impl Hearth.Notifications.Message
  def via(%__MODULE__{setting: nil}, %User{}), do: [:in_app, :web_push]

  def via(%__MODULE__{setting: setting}, %User{settings: settings}) do
    case Map.get(settings.notification_prefs, setting, true) do
      false -> []
      _on -> [:in_app, :web_push]
    end
  end

  def via(%__MODULE__{}, _notifiable), do: []

  @impl Hearth.Notifications.Message
  def to_in_app(%__MODULE__{in_app: in_app}, _notifiable), do: in_app

  @impl Hearth.Notifications.Message
  def to_web_push(%__MODULE__{} = notice, _notifiable) do
    %WebPushMessage{
      title: notice.title,
      body: notice.body,
      url: notice.url,
      tag: Atom.to_string(notice.in_app.kind)
    }
  end
end
