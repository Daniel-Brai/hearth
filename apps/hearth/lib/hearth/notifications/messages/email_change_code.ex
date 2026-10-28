defmodule Hearth.Notifications.EmailChangeCode do
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
    |> MailMessage.subject("#{code} is your code to change your #{brand} email")
    |> MailMessage.greeting("Confirm your new email")
    |> MailMessage.line("Someone asked to move a #{brand} account to this address.")
    |> MailMessage.line("Type this code in Settings to finish.")
    |> MailMessage.code(code)
    |> MailMessage.line("It works once, for the next #{ttl} minutes.")
    |> MailMessage.line("Didn't ask for this? Ignore it, and nothing changes.")
  end
end
