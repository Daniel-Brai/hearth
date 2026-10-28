defmodule Hearth.Notifications.Listener.Communities do
  use GenServer

  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Communities
  alias Hearth.Communities.InvitesEmailed
  alias Hearth.Notifications
  alias Hearth.Notifications.Anonymous
  alias Hearth.Notifications.CommunityInvite
  alias Hearth.Notifications.Notices

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Communities.subscribe_to_pubsub()

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(%InvitesEmailed{} = event, state) do
    for %{email: email, code: code} <- event.invites do
      message = %CommunityInvite{
        community_name: event.community_name,
        inviter_name: event.inviter_name,
        note: event.note,
        code: code
      }

      recipient = recipient(email)
      Notifications.send(recipient, message)
      tell_in_app(recipient, event, code)
    end

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}

  # Someone with an account also finds the invite in the app
  defp tell_in_app(%User{} = user, event, code) do
    notice =
      Notices.invite(%{
        community_id: event.community_id,
        community_name: event.community_name,
        inviter_id: event.inviter_id,
        inviter_name: event.inviter_name,
        code: code
      })

    Notifications.send(user, notice)
  end

  defp tell_in_app(_anonymous, _event, _code), do: :ok

  defp recipient(email) do
    case Accounts.get_user(email: email) do
      {:ok, user} -> user
      {:error, :not_found} -> %Anonymous{email: email}
    end
  end
end
