defmodule Hearth.Notifications.Message do
  alias Hearth.Notifications.InAppMessage
  alias Hearth.Notifications.MailMessage
  alias Hearth.Notifications.WebPushMessage

  @type channel :: :mail | :web_push | :in_app

  @callback via(message :: struct(), notifiable :: struct()) :: [channel()]
  @callback to_mail(message :: struct(), notifiable :: struct()) :: MailMessage.t()
  @callback to_web_push(message :: struct(), notifiable :: struct()) :: WebPushMessage.t()
  @callback to_in_app(message :: struct(), notifiable :: struct()) :: InAppMessage.t()

  @optional_callbacks to_mail: 2, to_web_push: 2, to_in_app: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Hearth.Notifications.Message
    end
  end
end
