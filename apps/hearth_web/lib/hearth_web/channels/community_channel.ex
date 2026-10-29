defmodule HearthWeb.CommunityChannel do
  use HearthWeb, :channel

  alias Hearth.Common
  alias Hearth.Communities
  alias HearthWeb.Endpoint
  alias Phoenix.Socket
  alias Phoenix.Socket.Broadcast

  @impl Phoenix.Channel
  def join("community:" <> id, _payload, socket) do
    %Socket{assigns: %{auth: auth}} = socket

    case authorized?(auth, id) do
      true ->
        # Events about rooms come through here so private ones reach only those who can see them
        :ok = Endpoint.subscribe("rooms:" <> id)
        {:ok, socket |> assign(:community_id, id) |> put_hidden_room_ids()}

      false ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  # Only the community goes out, so a private room's id never reaches people who can't see it
  @impl Phoenix.Channel
  def handle_info(%Broadcast{event: "RoomAccessChanged"} = broadcast, socket) do
    :ok = push(socket, "room_access_changed", %{community_id: broadcast.payload.community_id})
    {:noreply, put_hidden_room_ids(socket)}
  end

  # A new room may be private, so who can see it is worked out before it goes out
  def handle_info(%Broadcast{event: "RoomChanged"} = broadcast, socket),
    do: socket |> put_hidden_room_ids() |> push_visible(broadcast)

  def handle_info(%Broadcast{topic: "rooms:" <> _id} = broadcast, socket),
    do: push_visible(socket, broadcast)

  defp authorized?(auth, id) do
    with true <- Common.valid_id?(id),
         {:ok, community} <- Communities.get_community(id: id) do
      Communities.readable?(community, auth)
    else
      false -> false
      {:error, _reason} -> false
    end
  end

  defp put_hidden_room_ids(socket) do
    %Socket{assigns: %{auth: auth, community_id: id}} = socket
    assign(socket, :hidden_room_ids, Communities.hidden_room_ids(auth, [id]))
  end

  defp push_visible(socket, broadcast) do
    %Broadcast{event: event, payload: payload} = broadcast

    if Map.get(payload, :room_id) not in socket.assigns.hidden_room_ids do
      :ok = push(socket, event, payload)
    end

    {:noreply, socket}
  end
end
