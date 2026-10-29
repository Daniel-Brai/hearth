defmodule HearthWeb.RoomChannel do
  use HearthWeb, :channel

  alias Hearth.Chat
  alias Hearth.Common
  alias Hearth.Communities
  alias HearthWeb.Endpoint
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
  def handle_info(%Broadcast{event: "RoomAccessChanged"}, socket) do
    %Socket{assigns: %{auth: auth, room: room}} = socket

    case Communities.view_room(auth, id: room.id) do
      {:ok, _room} ->
        {:noreply, socket}

      {:error, :not_found} ->
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
