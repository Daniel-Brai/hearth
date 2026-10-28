defmodule HearthWeb.FakeBrowser do
  use GenServer

  import Phoenix.ChannelTest, only: [join: 4, push: 3]

  alias ExRTCP.Packet.PayloadFeedback.PLI
  alias ExRTP.Packet
  alias ExWebRTC.ICECandidate
  alias ExWebRTC.MediaStreamTrack
  alias ExWebRTC.PeerConnection
  alias ExWebRTC.SessionDescription
  alias Phoenix.Socket.Message

  def start!(socket, session_id, name, payload \\ %{}) do
    {:ok, browser} = GenServer.start_link(__MODULE__, {socket, session_id, name, self(), payload})
    {browser, GenServer.call(browser, :reply)}
  end

  def send_media(browser, kind, payload), do: GenServer.call(browser, {:send, kind, payload})

  def stream(browser, kind, payload, count),
    do: GenServer.cast(browser, {:stream, kind, payload, count})

  def ask_keyframe(browser, user_id), do: GenServer.call(browser, {:pli, user_id})

  def stop(browser), do: GenServer.stop(browser)

  @impl GenServer
  def init({socket, session_id, name, test, payload}) do
    socket = %{socket | transport_pid: self()}

    case join(socket, HearthWeb.VoiceChannel, "voice:#{session_id}", payload) do
      {:ok, reply, channel} ->
        {:ok, pc} = PeerConnection.start_link()

        {:ok,
         %{
           name: name,
           test: test,
           reply: reply,
           channel: channel,
           pc: pc,
           tracks: %{},
           sending: %{},
           sequence: 0
         }}

      {:error, reply} ->
        {:ok, %{reply: {:error, reply}, pc: nil}}
    end
  end

  @impl GenServer
  def handle_call(:reply, _from, state), do: {:reply, state.reply, state}

  def handle_call({:send, kind, payload}, _from, state) do
    {:reply, :ok, send_packet(state, kind, payload)}
  end

  def handle_call({:pli, user_id}, _from, state) do
    track_id =
      state.pc
      |> PeerConnection.get_transceivers()
      |> Enum.find_value(fn tr ->
        if state.tracks[tr.mid] == %{user_id: user_id, kind: :video},
          do: tr.receiver.track.id
      end)

    {:reply, PeerConnection.send_pli(state.pc, track_id), state}
  end

  @impl GenServer
  def handle_cast({:stream, kind, payload, count}, state) do
    send(self(), {:stream, kind, payload, count})
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%Message{event: "offer", payload: %{sdp: sdp, tracks: tracks}}, state) do
    :ok =
      PeerConnection.set_remote_description(state.pc, %SessionDescription{type: :offer, sdp: sdp})

    state = attach_tracks(state, tracks)

    {:ok, answer} = PeerConnection.create_answer(state.pc)
    :ok = PeerConnection.set_local_description(state.pc, answer)
    push(state.channel, "answer", %{"sdp" => answer.sdp})

    received =
      for {mid, %{direction: :receive, user_id: user_id, kind: kind}} <- tracks,
          into: %{},
          do: {mid, %{user_id: user_id, kind: kind}}

    {:noreply, %{state | tracks: Map.merge(state.tracks, received)}}
  end

  def handle_info(%Message{event: "candidate", payload: %{candidate: candidate}}, state) do
    :ok = PeerConnection.add_ice_candidate(state.pc, ICECandidate.from_json(candidate))
    {:noreply, state}
  end

  def handle_info(%Message{event: event, payload: payload}, state) do
    send(state.test, {:browser, state.name, {:push, event, payload}})
    {:noreply, state}
  end

  def handle_info({:ex_webrtc, _pc, {:ice_candidate, candidate}}, state) do
    push(state.channel, "candidate", %{"candidate" => ICECandidate.to_json(candidate)})
    {:noreply, state}
  end

  def handle_info({:ex_webrtc, _pc, {:connection_state_change, :connected}}, state) do
    send(state.test, {:browser, state.name, :connected})
    {:noreply, state}
  end

  def handle_info({:ex_webrtc, pc, {:rtp, track_id, _rid, packet}}, state) do
    source =
      pc
      |> PeerConnection.get_transceivers()
      |> Enum.find_value(fn tr ->
        if tr.receiver.track.id == track_id, do: state.tracks[tr.mid]
      end)

    if source do
      send(
        state.test,
        {:browser, state.name, {:rtp, source.user_id, source.kind, packet.payload}}
      )
    end

    {:noreply, state}
  end

  def handle_info({:ex_webrtc, _pc, {:rtcp, packets}}, state) do
    if Enum.any?(packets, &match?({_track, %PLI{}}, &1)) do
      send(state.test, {:browser, state.name, :pli})
    end

    {:noreply, state}
  end

  def handle_info({:stream, _kind, _payload, 0}, state), do: {:noreply, state}

  def handle_info({:stream, kind, payload, count}, state) do
    Process.send_after(self(), {:stream, kind, payload, count - 1}, 20)
    {:noreply, send_packet(state, kind, payload)}
  end

  def handle_info(_message, state), do: {:noreply, state}

  # Nothing is sent before the server asks for this kind, as with a screen
  # picked before the offer that carries it.
  defp send_packet(state, kind, _payload) when not is_map_key(state.sending, kind), do: state

  defp send_packet(state, kind, payload) do
    packet =
      Packet.new(payload,
        sequence_number: state.sequence,
        timestamp: state.sequence * 960,
        marker: kind == :video
      )

    :ok = PeerConnection.send_rtp(state.pc, state.sending[kind], packet)
    %{state | sequence: state.sequence + 1}
  end

  # Puts a microphone or screen on each transceiver the server wants to
  # receive on, as the web app does before answering.
  defp attach_tracks(state, tracks) do
    transceivers = PeerConnection.get_transceivers(state.pc)

    Enum.reduce(tracks, state, fn
      {mid, %{direction: :send, kind: kind}}, state when not is_map_key(state.sending, kind) ->
        tr = Enum.find(transceivers, &(&1.mid == mid))
        track = MediaStreamTrack.new(kind)
        :ok = PeerConnection.set_transceiver_direction(state.pc, tr.id, :sendrecv)
        :ok = PeerConnection.replace_track(state.pc, tr.sender.id, track)
        %{state | sending: Map.put(state.sending, kind, track.id)}

      _other, state ->
        state
    end)
  end
end
