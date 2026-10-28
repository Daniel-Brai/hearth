defmodule HearthWeb.UserChannel do
  use HearthWeb, :channel

  alias Hearth.Accounts
  alias HearthWeb.Presence
  alias Phoenix.Socket

  @impl Phoenix.Channel
  def join("user:" <> id, _payload, %Socket{assigns: %{auth: %{id: id}}} = socket) do
    send(self(), :track)
    {:ok, socket}
  end

  def join("user:" <> _id, _payload, _socket), do: {:error, %{reason: "unauthorized"}}

  @impl Phoenix.Channel
  def handle_info(:track, %Socket{assigns: %{auth: auth}} = socket) do
    {:ok, _ref} = Presence.track_user(self(), auth.id)
    :ok = Accounts.touch_last_seen(auth)

    {:noreply, socket}
  end

  # Last seen is when the app was last open so leaving marks it too. A refused join
  # never opened anything
  @impl Phoenix.Channel
  def terminate(_reason, %Socket{joined: true, assigns: %{auth: auth}}),
    do: Accounts.touch_last_seen(auth)

  def terminate(_reason, %Socket{}), do: :ok
end
