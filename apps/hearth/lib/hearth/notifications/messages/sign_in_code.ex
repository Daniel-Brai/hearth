defmodule Hearth.Notifications.SignInCode do
  use Hearth.Notifications.Message

  alias Hearth.Notifications
  alias Hearth.Notifications.MailMessage

  @fields [:code, :ttl]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{code: String.t(), ttl: pos_integer()}

  @impl Hearth.Notifications.Message
  def via(%__MODULE__{}, _notifiable), do: [:mail]

  @impl Hearth.Notifications.Message
  def to_mail(%__MODULE__{code: code, ttl: ttl}, _notifiable) do
    brand = Notifications.brand()

    %MailMessage{}
    |> MailMessage.subject("#{code} is your #{brand} sign in code")
    |> MailMessage.greeting("Here's your sign in code")
    |> MailMessage.line("Type it on the sign in screen. No password to remember.")
    |> MailMessage.code(code)
    |> MailMessage.line("It works once, for the next #{ttl} minutes.")
    |> MailMessage.line("Didn't ask for this? Ignore it. Nobody can sign in without this email.")
  end
end
