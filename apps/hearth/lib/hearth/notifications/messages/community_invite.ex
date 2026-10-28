defmodule Hearth.Notifications.CommunityInvite do
  use Hearth.Notifications.Message

  alias Hearth.Notifications
  alias Hearth.Notifications.MailMessage

  @enforce_keys ~w[community_name inviter_name code]a
  defstruct ~w[community_name inviter_name code note]a

  @type t :: %__MODULE__{
          community_name: String.t(),
          inviter_name: String.t(),
          note: nil | String.t(),
          code: String.t()
        }

  @impl Hearth.Notifications.Message
  def via(%__MODULE__{}, _notifiable), do: [:mail]

  @impl Hearth.Notifications.Message
  def to_mail(%__MODULE__{} = message, _notifiable) do
    %MailMessage{}
    |> MailMessage.subject("#{message.inviter_name} invited you to #{message.community_name}")
    |> MailMessage.greeting("You're invited to #{message.community_name}")
    |> MailMessage.line(
      "#{message.inviter_name} invited you to join #{message.community_name} on #{Notifications.brand()}."
    )
    |> note(message)
    |> MailMessage.line("No account yet? You make one on the same screen.")
    |> MailMessage.action(
      "Join #{message.community_name}",
      Notifications.url("/join/#{message.code}")
    )
    |> MailMessage.line("This invite is for you alone. It works once, for 14 days.")
  end

  defp note(mail, %__MODULE__{note: nil}), do: mail

  defp note(mail, %__MODULE__{note: note, inviter_name: inviter}),
    do: MailMessage.line(mail, "#{inviter} wrote: “#{note}”")
end
