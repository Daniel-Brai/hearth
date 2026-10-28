defmodule Hearth.Notifications.EmailChanged do
  use Hearth.Notifications.Message

  alias Hearth.Notifications
  alias Hearth.Notifications.MailMessage

  @fields ~w[new_email undo_token ttl]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{new_email: String.t(), undo_token: String.t(), ttl: pos_integer()}

  @impl Hearth.Notifications.Message
  def via(%__MODULE__{}, _notifiable), do: [:mail]

  # The token goes in the fragment so it stays out of access logs
  @impl Hearth.Notifications.Message
  def to_mail(%__MODULE__{} = message, _notifiable) do
    brand = Notifications.brand()
    days = div(message.ttl, 24 * 60)
    undo_url = Notifications.url("/settings/email/undo#token=#{message.undo_token}")

    %MailMessage{}
    |> MailMessage.error()
    |> MailMessage.subject("Your #{brand} email was changed")
    |> MailMessage.greeting("Your email was changed")
    |> MailMessage.line("Your #{brand} account now signs in with #{message.new_email}.")
    |> MailMessage.line("Wasn't you? Undo it, and every device gets signed out.")
    |> MailMessage.action("Undo this change", undo_url)
    |> MailMessage.line("The link works for #{days} days.")
  end
end
