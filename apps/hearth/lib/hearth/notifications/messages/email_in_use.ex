defmodule Hearth.Notifications.EmailInUse do
  use Hearth.Notifications.Message

  alias Hearth.Notifications
  alias Hearth.Notifications.MailMessage

  defstruct []

  @type t :: %__MODULE__{}

  @impl Hearth.Notifications.Message
  def via(%__MODULE__{}, _notifiable), do: [:mail]

  @impl Hearth.Notifications.Message
  def to_mail(%__MODULE__{}, _notifiable) do
    brand = Notifications.brand()

    %MailMessage{}
    |> MailMessage.subject("Someone tried to use your email on #{brand}")
    |> MailMessage.greeting("This email already has an account")
    |> MailMessage.line(
      "Someone asked to move another #{brand} account to this address. " <>
        "It already belongs to your account, so nothing changed."
    )
    |> MailMessage.line("If that was you, sign in with this email instead.")
    |> MailMessage.action("Sign in", Notifications.url("/signin"))
  end
end
