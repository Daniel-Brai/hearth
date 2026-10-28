defmodule Hearth.Notifications.Listener.Auth do
  use GenServer

  alias Hearth.Accounts
  alias Hearth.Auth
  alias Hearth.Auth.EmailChangeBlocked
  alias Hearth.Auth.EmailChangeCodeRequested
  alias Hearth.Auth.EmailChangeConfirmed
  alias Hearth.Auth.SignInCodeRequested
  alias Hearth.Auth.TransferCodeRequested
  alias Hearth.Notifications
  alias Hearth.Notifications.Anonymous
  alias Hearth.Notifications.EmailChangeCode
  alias Hearth.Notifications.EmailChanged
  alias Hearth.Notifications.EmailInUse
  alias Hearth.Notifications.SignInCode
  alias Hearth.Notifications.TransferCode

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Auth.subscribe_to_pubsub()

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(%SignInCodeRequested{} = event, state) do
    recipient =
      case Accounts.get_user(email: event.email) do
        {:ok, user} -> user
        {:error, :not_found} -> %Anonymous{email: event.email}
      end

    Notifications.send(recipient, %SignInCode{code: event.code, ttl: event.ttl})

    {:noreply, state}
  end

  def handle_info(%EmailChangeCodeRequested{} = event, state) do
    with {:ok, user} <- Accounts.get_user(id: event.user_id) do
      recipient = %Anonymous{name: name(user), email: event.email}

      Notifications.send(recipient, %EmailChangeCode{code: event.code, ttl: event.ttl})
    end

    {:noreply, state}
  end

  def handle_info(%TransferCodeRequested{} = event, state) do
    with {:ok, user} <- Accounts.get_user(id: event.user_id) do
      message = %TransferCode{
        community_name: event.community_name,
        code: event.code,
        ttl: event.ttl
      }

      Notifications.send(%Anonymous{name: name(user), email: event.email}, message)
    end

    {:noreply, state}
  end

  def handle_info(%EmailChangeBlocked{} = event, state) do
    Notifications.send(%Anonymous{email: event.email}, %EmailInUse{})

    {:noreply, state}
  end

  def handle_info(%EmailChangeConfirmed{} = event, state) do
    with {:ok, user} <- Accounts.get_user(id: event.user_id) do
      recipient = %Anonymous{name: name(user), email: event.old_email}

      message = %EmailChanged{
        new_email: event.new_email,
        undo_token: event.undo_token,
        ttl: event.ttl
      }

      Notifications.send(recipient, message)
    end

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}

  defp name(user), do: user.display_name || user.username
end
