defmodule HearthWeb.VoiceChannel do
  use HearthWeb, :channel

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Voice
  alias HearthWeb.Endpoint
  alias HearthWeb.FloodGuard
  alias Phoenix.Socket
  alias Phoenix.Socket.Broadcast

  @reactions_per_second 5

  @impl Phoenix.Channel
  def join("voice:" <> id, payload, socket) do
    %Socket{assigns: %{auth: auth}} = socket

    with true <- Common.valid_id?(id),
         {:ok, session} <- Voice.get_session(id: id),
         {:ok, _room} <- Communities.view_room(auth, id: session.room_id),
         {:ok, joined} <- Voice.join(auth, session, self(), stage: payload["stage"] != false) do
      Process.monitor(joined.peer)
      # Access changes are told on the community's rooms topic
      :ok = Endpoint.subscribe("rooms:" <> session.community_id)

      socket = assign(socket, peer: joined.peer, session: session)
      {:ok, joined_reply(auth, joined), socket}
    else
      false -> error_reply(:not_found)
      {:error, reason} -> error_reply(reason)
    end
  end

  @impl Phoenix.Channel
  def handle_in("answer", %{"sdp" => sdp}, socket) when is_binary(sdp) do
    case Voice.answer(socket.assigns.peer, sdp) do
      :ok -> {:reply, :ok, socket}
      {:error, _reason} -> {:reply, error_reply(:invalid_answer), socket}
    end
  end

  def handle_in("candidate", %{"candidate" => candidate}, socket)
      when is_map(candidate) or is_nil(candidate) do
    :ok = Voice.candidate(socket.assigns.peer, candidate)
    {:noreply, socket}
  end

  def handle_in("ice_restart", _payload, socket) do
    ice_servers = Voice.ice_restart(socket.assigns.auth, socket.assigns.peer)
    {:reply, {:ok, %{ice_servers: ice_servers}}, socket}
  end

  def handle_in("react", %{"emoji" => emoji}, socket) when is_binary(emoji) do
    %Socket{assigns: %{auth: auth, session: session}} = socket

    # A burst past the limit is dropped quietly, since a reaction is only decoration.
    with {:allow, _count} <- FloodGuard.hit("voice-react:#{auth.id}", 1000, @reactions_per_second),
         {:error, reason} <- Voice.react(auth, session, emoji) do
      {:reply, error_reply(reason), socket}
    else
      _sent_or_dropped -> {:noreply, socket}
    end
  end

  def handle_in("captions", %{"on" => on}, socket) when is_boolean(on) do
    %Socket{assigns: %{auth: auth, session: session}} = socket

    case Voice.captions(auth, session, on) do
      :ok -> {:reply, :ok, socket}
      {:error, reason} -> {:reply, error_reply(reason), socket}
    end
  end

  def handle_in(_event, _payload, socket), do: {:reply, error_reply(:unknown), socket}

  @impl Phoenix.Channel
  def handle_info({:hearth_rtc, :offer, offer}, socket) do
    push(socket, "offer", offer)
    {:noreply, socket}
  end

  def handle_info({:hearth_rtc, :candidate, candidate}, socket) do
    push(socket, "candidate", %{candidate: candidate})
    {:noreply, socket}
  end

  def handle_info({:hearth_rtc, :closed, reason}, socket), do: disconnected(socket, reason)

  # The peer went away without saying why, so the browser should rejoin.
  def handle_info({:DOWN, _ref, :process, peer, _reason}, %{assigns: %{peer: peer}} = socket),
    do: disconnected(socket, :lost)

  def handle_info(%Broadcast{event: "RoomAccessChanged"}, socket) do
    %Socket{assigns: %{auth: auth, session: session}} = socket

    case Communities.view_room(auth, id: session.room_id) do
      {:ok, _room} ->
        {:noreply, socket}

      {:error, :not_found} ->
        :ok = push(socket, "room_hidden", %{room_id: session.room_id})
        {:stop, {:shutdown, :left}, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # Leaving on purpose takes the person out at once. A dropped socket keeps
  # their place for the grace period, in case they come back.
  @impl Phoenix.Channel
  def terminate({:shutdown, :left}, socket) do
    _left = Voice.leave(socket.assigns.auth, socket.assigns.session)
    :ok
  end

  def terminate(_reason, _socket), do: :ok

  defp error_reply(reason), do: {:error, %{reason: Atom.to_string(reason)}}

  defp disconnected(socket, reason) do
    push(socket, "Disconnected", %{reason: reason})
    {:stop, :normal, socket}
  end

  defp joined_reply(auth, %{snapshot: snapshot, ice_servers: ice_servers}) do
    me = Enum.find(snapshot.participants, &(&1.user_id == auth.id))

    %{
      ice_servers: ice_servers,
      me: Map.take(me, [:role, :server_muted]),
      mode: snapshot.mode,
      share: snapshot.share,
      recording: snapshot.recording,
      hands: snapshot.hands,
      speaking: snapshot.speaking,
      participants:
        Enum.map(
          snapshot.participants,
          &Map.take(&1, ~w[user_id role hand_raised_at self_muted server_muted]a)
        )
    }
  end
end
