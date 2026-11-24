defmodule HearthWeb.RoomChannel do
  use HearthWeb, :channel

  alias Hearth.Chat
  alias Hearth.Common
  alias Hearth.Communities
  alias HearthWeb.Endpoint
  alias HearthWeb.Typing
  alias Phoenix.Socket
  alias Phoenix.Socket.Broadcast

  @impl Phoenix.Channel
  def join("room:" <> id, _payload, socket) do
    %Socket{assigns: %{auth: auth}} = socket

    # Access changes are told on the community's rooms topic
    with {:ok, room} <- authorized(auth, id),
         :ok <- Endpoint.subscribe("rooms:" <> room.community_id) do
      {:ok, assign(socket, :room, room)}
    else
      _denied -> {:error, %{reason: "unauthorized"}}
    end
  end

  @impl Phoenix.Channel
  def handle_in("typing", %{"typing" => typing}, socket) when is_boolean(typing) do
    :ok = Typing.relay(socket, socket.assigns.room, typing)
    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket), do: {:reply, {:error, %{reason: "unknown"}}, socket}

  @impl Phoenix.Channel
  # A change about one other member leaves this socket as it is
  def handle_info(
        %Broadcast{event: "RoomAccessChanged", payload: %{user_id: user_id}},
        %Socket{assigns: %{auth: %{id: me}}} = socket
      )
      when user_id not in [nil, me],
      do: {:noreply, socket}

  # The room is read again since its own access may be what changed
  def handle_info(%Broadcast{event: "RoomAccessChanged"}, socket) do
    %Socket{assigns: %{auth: auth, room: room}} = socket

    with {:ok, room} <- Communities.get_room(id: room.id),
         true <- Chat.can_read?(auth, room) do
      {:noreply, socket}
    else
      _denied ->
        :ok = push(socket, "room_hidden", %{room_id: room.id})
        {:stop, :normal, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp authorized(auth, id) do
    with true <- Common.valid_id?(id),
         {:ok, room} <- Communities.view_room(auth, id: id),
         true <- Chat.can_read?(auth, room) do
      {:ok, room}
    end
  end
end
