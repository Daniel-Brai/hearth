defmodule Hearth.Notifications.TransferCode do
  use Hearth.Notifications.Message

  alias Hearth.Notifications.MailMessage

  @fields ~w[community_name code ttl]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{community_name: String.t(), code: String.t(), ttl: pos_integer()}

  @impl Hearth.Notifications.Message
  def via(%__MODULE__{}, _notifiable), do: [:mail]

  @impl Hearth.Notifications.Message
  def to_mail(%__MODULE__{community_name: name, code: code, ttl: ttl}, _notifiable) do
    %MailMessage{}
    |> MailMessage.subject("#{code} is your code to hand over #{name}")
    |> MailMessage.greeting("Confirm the new owner")
    |> MailMessage.line("You asked to make someone else the owner of #{name}.")
    |> MailMessage.line("Type this code in Edit community to finish.")
    |> MailMessage.code(code)
    |> MailMessage.line("It works once, for the next #{ttl} minutes.")
    |> MailMessage.line("Didn't ask for this? Ignore it, and nothing changes.")
  end
end
