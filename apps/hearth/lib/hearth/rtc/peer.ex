defmodule Hearth.RTC.Peer do
  # The server makes every offer so there is never glare
  # Packets are forwarded without decoding, straight to each subscriber's connection

  use GenServer, restart: :temporary

  alias ExRTCP.Packet.PayloadFeedback.PLI
  alias ExRTP.Packet
  alias ExRTP.Packet.Extension.AudioLevel
  alias ExSDP.Attribute.FMTP
  alias ExWebRTC.ICECandidate
  alias ExWebRTC.MediaStreamTrack
  alias ExWebRTC.PeerConnection
  alias ExWebRTC.RTPCodecParameters
  alias ExWebRTC.SessionDescription
  alias Hearth.Common.T
  alias Hearth.RTC
  alias Hearth.RTC.Recorder

  require Logger

  @audio_level_uri "urn:ietf:params:rtp-hdrext:ssrc-audio-level"
  @mid_uri "urn:ietf:params:rtp-hdrext:sdes:mid"
  @rid_uri "urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id"

  # A packet at or under this level in -dBov counts as speech
  # and speech stops counting this long after the last one
  @loud_level 50
  @speaking_ms 400
  @keyframe_ms 500
  @failed_ms 10_000

  # While captions are on a stretch of speech goes for captioning when the speaker pauses or
  # reaches the longest stretch, and one shorter than the least is a cough or a click
  @phrase_max_ms 6_000
  @phrase_min_ms 600

  @type route :: %{
          send_audio: boolean(),
          send_video: boolean(),
          muted: boolean(),
          receive: [{T.id(), :audio | :video}],
          record: nil | Recorder.recording(),
          caption: boolean()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @spec route(pid(), route()) :: :ok
  def route(peer, route), do: GenServer.cast(peer, {:route, route})

  # Waits until earlier routes are handled so a stopped recording's files are closed
  @spec flush(pid()) :: :ok
  def flush(peer), do: GenServer.call(peer, :flush)

  @spec answer(pid(), String.t()) :: :ok | {:error, term()}
  def answer(peer, sdp) when is_binary(sdp), do: GenServer.call(peer, {:answer, sdp})

  @spec candidate(pid(), nil | map()) :: :ok
  def candidate(peer, candidate), do: GenServer.cast(peer, {:candidate, candidate})

  @spec ice_restart(pid()) :: :ok
  def ice_restart(peer), do: GenServer.cast(peer, :ice_restart)

  @spec keyframe(pid()) :: :ok
  def keyframe(peer), do: GenServer.cast(peer, :keyframe)

  @spec attach(pid(), pid()) :: :ok
  def attach(peer, live), do: GenServer.cast(peer, {:attach, live})

  @spec close(pid(), atom()) :: :ok
  def close(peer, reason) when is_atom(reason), do: GenServer.cast(peer, {:close, reason})

  @impl GenServer
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    user_id = Keyword.fetch!(opts, :user_id)
    channel = Keyword.fetch!(opts, :channel)
    config = Keyword.fetch!(opts, :config)

    Process.flag(:trap_exit, true)
    Process.monitor(channel)

    {:ok, pc} = config |> pc_options() |> PeerConnection.start_link()
    :ok = RTC.join({:peer, session_id, user_id})
    :ok = RTC.join(:peers)

    state = %{
      ready_ms: config[:ready_ms] || 10_000,
      offered?: false,
      session_id: session_id,
      user_id: user_id,
      channel: channel,
      live: Keyword.fetch!(opts, :live),
      pc: pc,
      route: %{
        send_audio: false,
        send_video: false,
        muted: false,
        receive: [],
        record: nil,
        caption: false
      },
      segments: %{},
      inbound: %{},
      in_tracks: %{},
      outbound: %{},
      out_tracks: %{},
      negotiating?: false,
      pending?: false,
      ice_restart?: false,
      new_watch?: false,
      level_id: nil,
      loud_at: nil,
      speaking?: false,
      phrase: nil,
      keyframe_at: nil,
      keyframe_due?: false,
      connected?: false,
      failed_timer: nil
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:route, route}, state) do
    state = close_segments(%{state | route: route}, state.route.record)

    case state.negotiating? do
      true -> {:noreply, %{state | pending?: true}}
      false -> {:noreply, apply_route(state)}
    end
  end

  def handle_cast({:candidate, nil}, state), do: {:noreply, state}

  def handle_cast({:candidate, %{} = json}, state) do
    case PeerConnection.add_ice_candidate(state.pc, ICECandidate.from_json(json)) do
      :ok -> :ok
      {:error, reason} -> Logger.debug("Voice candidate refused: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_cast(:ice_restart, state) do
    state = cancel_failed(%{state | ice_restart?: true})

    case state.negotiating? do
      true -> {:noreply, %{state | pending?: true}}
      false -> {:noreply, offer(state)}
    end
  end

  def handle_cast(:keyframe, state), do: {:noreply, request_keyframe(state)}

  def handle_cast({:attach, live}, state), do: {:noreply, %{state | live: live}}

  def handle_cast({:close, reason}, state) do
    send(state.channel, {:hearth_rtc, :closed, reason})
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_call(:flush, _from, state), do: {:reply, :ok, state}

  def handle_call({:answer, sdp}, _from, state) do
    description = %SessionDescription{type: :answer, sdp: sdp}

    case PeerConnection.set_remote_description(state.pc, description) do
      :ok ->
        state = %{state | negotiating?: false, level_id: level_id(state.pc)}

        # A watcher not connected yet gets the keyframe once it connects
        state =
          if state.new_watch? and state.connected?,
            do: ask_sharer_for_keyframe(state),
            else: state

        state = if state.pending?, do: apply_route(%{state | pending?: false}), else: state

        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_info({:ex_webrtc, pc, message}, %{pc: pc} = state), do: on_pc(message, state)

  def handle_info(:check_speaking, state), do: {:noreply, check_speaking(state)}

  def handle_info(:ready_timeout, %{connected?: true} = state), do: {:noreply, state}

  def handle_info(:ready_timeout, state), do: {:stop, {:shutdown, :not_connected}, state}

  def handle_info(:failed_timeout, state), do: {:stop, {:shutdown, :connection_failed}, state}

  def handle_info({:DOWN, _ref, :process, channel, _reason}, %{channel: channel} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, pc, reason}, %{pc: pc} = state), do: {:stop, reason, state}

  def handle_info(_message, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    for {_kind, segment} <- state.segments, segment != :failed, do: Recorder.close(segment)
    PeerConnection.close(state.pc)
  catch
    :exit, _reason -> :ok
  end

  defp on_pc({:rtp, track_id, _rid, packet}, state) do
    case Map.fetch(state.in_tracks, track_id) do
      {:ok, kind} -> {:noreply, state |> see(kind) |> forward(kind, packet)}
      :error -> {:noreply, state}
    end
  end

  defp on_pc({:rtcp, packets}, state) do
    wants_keyframe? =
      Enum.any?(packets, fn {track_id, packet} ->
        match?(%PLI{}, packet) and Map.has_key?(state.out_tracks, track_id)
      end)

    state = if wants_keyframe?, do: ask_sharer_for_keyframe(state), else: state
    {:noreply, state}
  end

  defp on_pc({:ice_candidate, candidate}, state) do
    send(state.channel, {:hearth_rtc, :candidate, ICECandidate.to_json(candidate)})
    {:noreply, state}
  end

  defp on_pc({:connection_state_change, :connected}, state) do
    notify(state, :connected)
    state = cancel_failed(%{state | connected?: true})
    {:noreply, if(state.new_watch?, do: ask_sharer_for_keyframe(state), else: state)}
  end

  defp on_pc({:connection_state_change, :failed}, state) do
    notify(state, :failed)
    {:noreply, %{state | failed_timer: Process.send_after(self(), :failed_timeout, @failed_ms)}}
  end

  defp on_pc(_message, state), do: {:noreply, state}

  defp apply_route(state) do
    {inbound, changed_in?} = sync_inbound(state)
    {synced, changed_out?} = sync_outbound(inbound)

    if changed_in? or changed_out? or synced.ice_restart?, do: offer(synced), else: synced
  end

  defp sync_inbound(state) do
    wanted = %{audio: state.route.send_audio, video: state.route.send_video}

    Enum.reduce(wanted, {state, false}, fn {kind, wanted?}, {state, changed?} ->
      case {wanted?, Map.get(state.inbound, kind)} do
        {true, nil} ->
          {:ok, tr} = PeerConnection.add_transceiver(state.pc, kind, direction: :recvonly)
          track_id = tr.receiver.track.id
          entry = %{transceiver: tr.id, track: track_id, seen?: false}
          inbound = Map.put(state.inbound, kind, entry)
          {%{state | inbound: inbound, in_tracks: Map.put(state.in_tracks, track_id, kind)}, true}

        {false, %{transceiver: id, track: track_id}} ->
          :ok = PeerConnection.stop_transceiver(state.pc, id)
          inbound = Map.delete(state.inbound, kind)
          state = close_segment(state, kind)
          {%{state | inbound: inbound, in_tracks: Map.delete(state.in_tracks, track_id)}, true}

        _same ->
          {state, changed?}
      end
    end)
  end

  defp sync_outbound(state) do
    wanted = MapSet.new(state.route.receive)
    have = state.outbound |> Map.keys() |> MapSet.new()
    removed = MapSet.difference(have, wanted)
    added = MapSet.difference(wanted, have)
    new_watch? = Enum.any?(added, &match?({_user, :video}, &1))

    synced =
      removed
      |> Enum.reduce(state, &unsubscribe(&2, &1))
      |> then(&Enum.reduce(added, &1, fn source, acc -> subscribe(acc, source) end))
      |> Map.update!(:new_watch?, &(&1 or new_watch?))

    {synced, MapSet.size(added) > 0 or MapSet.size(removed) > 0}
  end

  defp subscribe(state, {publisher, kind} = source) do
    track = MediaStreamTrack.new(kind, [publisher])
    {:ok, tr} = PeerConnection.add_transceiver(state.pc, track, direction: :sendonly)
    {:ok, _owner} = Registry.register(Hearth.RTC.Tracks, key(state, source), {state.pc, track.id})

    entry = %{transceiver: tr.id, track: track.id}

    %{
      state
      | outbound: Map.put(state.outbound, source, entry),
        out_tracks: Map.put(state.out_tracks, track.id, source)
    }
  end

  defp unsubscribe(state, source) do
    %{transceiver: id, track: track_id} = Map.fetch!(state.outbound, source)
    :ok = Registry.unregister_match(Hearth.RTC.Tracks, key(state, source), {state.pc, track_id})
    :ok = PeerConnection.stop_transceiver(state.pc, id)

    %{
      state
      | outbound: Map.delete(state.outbound, source),
        out_tracks: Map.delete(state.out_tracks, track_id)
    }
  end

  defp offer(state) do
    {:ok, offer} = PeerConnection.create_offer(state.pc, ice_restart: state.ice_restart?)
    :ok = PeerConnection.set_local_description(state.pc, offer)

    send(state.channel, {:hearth_rtc, :offer, %{sdp: offer.sdp, tracks: tracks(state)}})

    # Someone with nothing to carry gets no offer so the wait for the
    # connection starts at the first one
    if not state.offered?, do: Process.send_after(self(), :ready_timeout, state.ready_ms)

    %{state | negotiating?: true, ice_restart?: false, offered?: true}
  end

  # Which transceiver is which, by mid so the browser can attach its
  # microphone or screen to the right one and label what it hears
  defp tracks(state) do
    sending =
      Map.new(state.inbound, fn {kind, %{transceiver: id}} ->
        {id, %{kind: kind, direction: :send, user_id: state.user_id}}
      end)

    receiving =
      Map.new(state.outbound, fn {{user_id, kind}, %{transceiver: id}} ->
        {id, %{kind: kind, direction: :receive, user_id: user_id}}
      end)

    meaning = Map.merge(sending, receiving)

    for tr <- PeerConnection.get_transceivers(state.pc),
        tr.mid != nil,
        not tr.stopping and not tr.stopped,
        %{} = info <- [Map.get(meaning, tr.id)],
        into: %{},
        do: {tr.mid, info}
  end

  defp forward(%{route: %{muted: true}} = state, _kind, _packet), do: state

  defp forward(state, kind, packet) do
    state = state |> hear(kind, packet) |> record(kind, packet) |> phrase(kind, packet)

    Registry.dispatch(Hearth.RTC.Tracks, key(state, {state.user_id, kind}), fn entries ->
      for {_owner, {pc, track_id}} <- entries, do: PeerConnection.send_rtp(pc, track_id, packet)
    end)

    state
  end

  defp key(state, {user_id, kind}), do: {state.session_id, user_id, kind}

  defp record(%{route: %{record: nil}} = state, _kind, _packet), do: state

  defp record(state, kind, packet) do
    case Map.fetch(state.segments, kind) do
      {:ok, :failed} ->
        state

      {:ok, segment} ->
        _written = Recorder.write(segment, packet)
        state

      :error ->
        case Recorder.open(state.route.record, state.user_id, kind) do
          {:ok, segment} ->
            _written = Recorder.write(segment, packet)

            starts_from_keyframe(
              %{state | segments: Map.put(state.segments, kind, segment)},
              kind
            )

          {:error, reason} ->
            Logger.warning("Voice recording file not opened: #{inspect(reason)}")
            %{state | segments: Map.put(state.segments, kind, :failed)}
        end
    end
  end

  # A share sends a keyframe only when asked, and a file that starts without one
  # can't be decoded, so a recording that starts mid share asks for one
  defp starts_from_keyframe(state, :video), do: request_keyframe(state)
  defp starts_from_keyframe(state, _kind), do: state

  # A recording that stopped or changed closes every file
  defp close_segments(%{route: %{record: same}} = state, same), do: state

  defp close_segments(state, _before) do
    state.segments |> Map.keys() |> Enum.reduce(state, &close_segment(&2, &1))
  end

  defp close_segment(state, kind) do
    case Map.pop(state.segments, kind) do
      {nil, _segments} ->
        state

      {segment, segments} ->
        if segment != :failed, do: Recorder.close(segment)
        %{state | segments: segments}
    end
  end

  defp phrase(%{route: %{caption: true}, speaking?: true} = state, :audio, packet) do
    now = System.monotonic_time(:millisecond)
    phrase = state.phrase || %{started_at: now, packets: []}
    state = %{state | phrase: %{phrase | packets: [packet | phrase.packets]}}

    if now - phrase.started_at >= @phrase_max_ms, do: hand_over_phrase(state), else: state
  end

  defp phrase(%{route: %{caption: false}, phrase: %{}} = state, _kind, _packet),
    do: %{state | phrase: nil}

  defp phrase(state, _kind, _packet), do: state

  defp hand_over_phrase(%{phrase: nil} = state), do: state

  defp hand_over_phrase(%{phrase: phrase} = state) do
    long_enough? = System.monotonic_time(:millisecond) - phrase.started_at >= @phrase_min_ms
    if long_enough?, do: notify(state, {:phrase, Enum.reverse(phrase.packets)})

    %{state | phrase: nil}
  end

  defp hear(state, :video, _packet), do: state

  defp hear(state, :audio, packet) do
    case loud?(state.level_id, packet) do
      true ->
        now = System.monotonic_time(:millisecond)
        state = %{state | loud_at: now}

        case state.speaking? do
          true ->
            state

          false ->
            notify(state, {:speaking, true})
            Process.send_after(self(), :check_speaking, @speaking_ms)
            %{state | speaking?: true}
        end

      false ->
        state
    end
  end

  defp loud?(nil, _packet), do: true

  defp loud?(id, packet) do
    with {:ok, raw} <- Packet.fetch_extension(packet, id),
         {:ok, %AudioLevel{level: level}} <- AudioLevel.from_raw(raw) do
      level <= @loud_level
    else
      _missing -> true
    end
  end

  defp check_speaking(%{speaking?: false} = state), do: state

  defp check_speaking(state) do
    quiet_for = System.monotonic_time(:millisecond) - (state.loud_at || 0)

    case quiet_for >= @speaking_ms do
      true ->
        notify(state, {:speaking, false})
        hand_over_phrase(%{state | speaking?: false})

      false ->
        Process.send_after(self(), :check_speaking, @speaking_ms - quiet_for)
        state
    end
  end

  defp ask_sharer_for_keyframe(state) do
    for {publisher, :video} <- Map.keys(state.outbound),
        peer <- RTC.members({:peer, state.session_id, publisher}),
        do: keyframe(peer)

    %{state | new_watch?: false}
  end

  # A keyframe asked for before the first video packet waits for it, since
  # the connection can't address the sharer's stream until then
  defp request_keyframe(state) do
    now = System.monotonic_time(:millisecond)

    case {state.inbound, state.keyframe_at} do
      {%{video: %{seen?: false}}, _at} ->
        %{state | keyframe_due?: true}

      {%{video: %{track: track_id}}, at} when at == nil or now - at >= @keyframe_ms ->
        PeerConnection.send_pli(state.pc, track_id)
        %{state | keyframe_at: now}

      _throttled ->
        state
    end
  end

  defp see(%{inbound: %{video: %{seen?: false} = video}} = state, :video) do
    state = %{state | inbound: %{state.inbound | video: %{video | seen?: true}}}

    case state.keyframe_due? do
      true -> request_keyframe(%{state | keyframe_due?: false})
      false -> state
    end
  end

  defp see(state, _kind), do: state

  defp notify(state, event), do: send(state.live, {:hearth_rtc_peer, state.user_id, event})

  defp cancel_failed(%{failed_timer: nil} = state), do: state

  defp cancel_failed(state) do
    Process.cancel_timer(state.failed_timer)
    %{state | failed_timer: nil}
  end

  defp level_id(pc) do
    pc
    |> PeerConnection.get_transceivers()
    |> Enum.flat_map(& &1.header_extensions)
    |> Enum.find_value(fn ext -> if ext.uri == @audio_level_uri, do: ext.id end)
  end

  @doc false
  @spec pc_options(keyword()) :: keyword()
  def pc_options(config) do
    opus = %RTPCodecParameters{
      payload_type: 111,
      mime_type: "audio/opus",
      clock_rate: 48_000,
      channels: 2,
      # Browsers answer with exactly this line, and ex_webrtc drops a codec whose
      # fmtp differs from the answer's, which leaves the receiver without one
      sdp_fmtp_line: %FMTP{pt: 111, minptime: 10, useinbandfec: true}
    }

    vp8 = %RTPCodecParameters{payload_type: 96, mime_type: "video/VP8", clock_rate: 90_000}

    options = [
      ice_servers: [],
      ice_port_range: config[:port_range] || [0],
      audio_codecs: [opus],
      video_codecs: [vp8],
      rtp_header_extensions: [
        %{type: :all, uri: @mid_uri},
        %{type: :video, uri: @rid_uri},
        %{type: :audio, uri: @audio_level_uri}
      ]
    ]

    put_mapper(options, config[:public_ip])
  end

  defp put_mapper(options, nil), do: options

  defp put_mapper(options, public_ip) do
    Keyword.put(options, :host_to_srflx_ip_mapper, fn
      ^public_ip -> nil
      _host -> public_ip
    end)
  end
end
