defmodule Hearth.Voice.Live do
  use GenServer, restart: :transient

  alias Hearth.Common.T
  alias Hearth.Events
  alias Hearth.PubSub
  alias Hearth.RTC
  alias Hearth.RTC.Peer
  alias Hearth.Voice
  alias Hearth.Voice.Captions
  alias Hearth.Voice.Capture
  alias Hearth.Voice.Command.ChangeParticipant
  alias Hearth.Voice.Command.EndSession
  alias Hearth.Voice.Command.StartRecording
  alias Hearth.Voice.Participant
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Session
  alias Hearth.Voice.State
  alias Hearth.Voice.VoiceAttendance
  alias Hearth.Voice.VoiceParticipantChanged
  alias Hearth.Voice.VoiceReaction
  alias Hearth.Voice.VoiceSessionEnded
  alias Hearth.Voice.VoiceShareChanged
  alias Hearth.Voice.VoiceSpeakingChanged

  require Logger

  @topic "voice"
  @max_starts 2
  @speaking_every 250

  @spec start_link(T.id()) :: GenServer.on_start()
  def start_link(session_id), do: GenServer.start_link(__MODULE__, session_id)

  @spec child_spec(T.id()) :: Supervisor.child_spec()
  def child_spec(session_id) do
    %{
      id: {__MODULE__, session_id},
      start: {__MODULE__, :start_link, [session_id]},
      restart: :transient
    }
  end

  @spec whereis(T.id()) :: nil | pid()
  def whereis(session_id), do: {:live, session_id} |> RTC.members() |> List.first()

  @spec join(pid(), T.id(), pid(), boolean(), boolean()) ::
          {:ok, %{peer: pid(), snapshot: map()}} | {:error, atom()}
  def join(live, user_id, channel, wants_stage?, may_speak?) do
    GenServer.call(live, {:join, user_id, channel, wants_stage?, may_speak?})
  end

  @spec act(pid(), atom() | tuple()) :: :ok | {:error, atom()}
  def act(live, action), do: GenServer.call(live, {:act, action})

  @spec lose(pid()) :: :ok
  def lose(live), do: GenServer.call(live, :lose)

  @spec snapshot(pid()) :: map()
  def snapshot(live), do: GenServer.call(live, :snapshot)

  @impl GenServer
  def init(session_id) do
    case Session.get(id: session_id) do
      %Session{ended_at: nil} = session -> start(session)
      _gone -> :ignore
    end
  end

  defp start(session) do
    case Session.count_restart(session.id) do
      starts when starts > @max_starts ->
        lose_session(session)
        :ignore

      _starts ->
        :ok = RTC.join({:live, session.id})
        rows = Participant.present(session.id)

        state = %{
          session: session,
          voice: State.new(session, rows, config(:room_limit)),
          rows: Map.new(rows, &{&1.user_id, &1}),
          peers: %{},
          refs: %{},
          graces: %{},
          speaking: MapSet.new(),
          said: MapSet.new(),
          speaking_timer: nil,
          empty_timer: nil,
          event_ends_at: event_ends_at(session),
          captions: MapSet.new(),
          recording: Recording.running(session.id)
        }

        state = adopt_peers(state)
        {:ok, sync(state)}
    end
  end

  # Peers survive a restart so find them again
  defp adopt_peers(state) do
    state.rows
    |> Map.keys()
    |> Enum.reduce(state, fn user_id, state ->
      case RTC.members({:peer, state.session.id, user_id}) do
        [peer | _rest] ->
          Peer.attach(peer, self())
          watch(state, user_id, peer)

        [] ->
          start_grace(state, user_id)
      end
    end)
  end

  @impl GenServer
  def handle_call({:join, user_id, channel, wants_stage?, may_speak?}, _from, state) do
    voice = state.voice

    with true <- State.room_for?(voice, user_id),
         {:ok, state} <- enter(state, user_id, wants_stage?, may_speak?),
         {:ok, peer} <- start_peer(state, user_id, channel) do
      state = state |> drop_peer(user_id) |> cancel_grace(user_id) |> watch(user_id, peer)
      :ok = Session.note_size(state.session.id, map_size(state.voice.people))
      announce(state, user_id)
      attendance(state)

      state = sync(state)
      {:reply, {:ok, %{peer: peer, snapshot: snapshot_of(state)}}, state}
    else
      false -> {:reply, {:error, :full}, state}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:act, action}, _from, state) do
    case act_on(action, state) do
      {:ok, state} -> {:reply, :ok, sync(state)}
      {:stop, state} -> {:stop, :normal, :ok, state}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call(:snapshot, _from, state), do: {:reply, snapshot_of(state), state}

  def handle_call(:lose, _from, state) do
    state = stop_recording(state, nil, :lost)
    {:ok, session} = EndSession.execute(state.session)
    close_all(state, :lost)
    broadcast(ended(session, :lost))

    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _peer, _reason}, state) do
    case Map.pop(state.refs, ref) do
      {nil, _refs} ->
        {:noreply, state}

      {user_id, refs} ->
        state = %{state | refs: refs, peers: Map.delete(state.peers, user_id)}
        state = speaking(state, user_id, false)

        case State.here?(state.voice, user_id) do
          true -> {:noreply, start_grace(state, user_id)}
          false -> {:noreply, state}
        end
    end
  end

  def handle_info({:grace_over, user_id}, state) do
    case Map.has_key?(state.peers, user_id) do
      true -> {:noreply, state}
      false -> {:noreply, state |> leave(user_id) |> sync()}
    end
  end

  def handle_info({:hearth_rtc_peer, user_id, {:phrase, packets}}, state) do
    _skipped_when_busy = Captions.caption(state.session.id, user_id, packets)
    {:noreply, state}
  end

  def handle_info({:hearth_rtc_peer, user_id, {:speaking, speaking?}}, state) do
    {:noreply, speaking(state, user_id, speaking?)}
  end

  def handle_info({:hearth_rtc_peer, _user_id, _event}, state), do: {:noreply, state}

  def handle_info(:empty, state) do
    case map_size(state.voice.people) do
      0 ->
        {:stop, state} = act_on(:end, state)
        {:stop, :normal, state}

      _here ->
        {:noreply, %{state | empty_timer: nil}}
    end
  end

  def handle_info(:flush_speaking, state),
    do: {:noreply, flush_speaking(%{state | speaking_timer: nil})}

  def handle_info(_message, state), do: {:noreply, state}

  defp enter(state, user_id, wants_stage?, may_speak?) do
    case State.here?(state.voice, user_id) do
      true ->
        {:ok, state}

      false ->
        role = State.role_on_join(state.voice, user_id, wants_stage?, may_speak?)

        with {:ok, row} <- Participant.enter(state.session.id, user_id, role) do
          voice = State.join(state.voice, user_id, State.person(row))
          {:ok, %{state | voice: voice, rows: Map.put(state.rows, user_id, row)}}
        end
    end
  end

  defp start_peer(state, user_id, channel) do
    RTC.start_peer(session_id: state.session.id, user_id: user_id, channel: channel, live: self())
  end

  defp watch(state, user_id, peer) do
    ref = Process.monitor(peer)
    %{state | peers: Map.put(state.peers, user_id, peer), refs: Map.put(state.refs, ref, user_id)}
  end

  # A person joining again replaces their old peer, whose connection is gone
  defp drop_peer(state, user_id) do
    case Map.pop(state.peers, user_id) do
      {nil, _peers} ->
        state

      {old, peers} ->
        {ref, _user} = Enum.find(state.refs, fn {_ref, user} -> user == user_id end)
        Process.demonitor(ref, [:flush])
        Peer.close(old, :replaced)
        %{state | peers: peers, refs: Map.delete(state.refs, ref)}
    end
  end

  defp start_grace(state, user_id) do
    state = cancel_grace(state, user_id)
    timer = Process.send_after(self(), {:grace_over, user_id}, config(:grace_ms))
    %{state | graces: Map.put(state.graces, user_id, timer)}
  end

  defp cancel_grace(state, user_id) do
    case Map.pop(state.graces, user_id) do
      {nil, _graces} ->
        state

      {timer, graces} ->
        Process.cancel_timer(timer)
        %{state | graces: graces}
    end
  end

  defp leave(state, user_id) do
    sharing? = state.voice.share == user_id

    case Map.fetch(state.rows, user_id) do
      {:ok, row} -> {:ok, _row} = Participant.put(row, %{left_at: DateTime.utc_now()})
      :error -> :ok
    end

    state = cancel_grace(state, user_id)

    gone = %{
      state
      | voice: State.leave(state.voice, user_id),
        rows: Map.delete(state.rows, user_id),
        captions: MapSet.delete(state.captions, user_id)
    }

    broadcast(%VoiceParticipantChanged{
      session_id: state.session.id,
      user_id: user_id,
      role: get_in(state.rows[user_id].role),
      hand_raised_at: nil,
      self_muted: true,
      server_muted: false,
      left: true
    })

    if sharing?, do: broadcast(%VoiceShareChanged{session_id: state.session.id, user_id: nil})
    attendance(gone)
    speaking(gone, user_id, false)
  end

  defp act_on({:react, user_id, emoji}, state) do
    with {:ok, _person} <- State.fetch(state.voice, user_id) do
      broadcast(%VoiceReaction{session_id: state.session.id, user_id: user_id, emoji: emoji})
      {:ok, state}
    end
  end

  defp act_on({:raise_hand, user_id}, state) do
    with {:ok, voice} <- State.raise_hand(state.voice, user_id, DateTime.utc_now()) do
      save(state, voice, user_id, nil)
    end
  end

  defp act_on({:lower_hand, user_id}, state) do
    with {:ok, voice} <- State.lower_hand(state.voice, user_id),
         do: save(state, voice, user_id, nil)
  end

  # Speech is turned into captions only while someone in the room has them on
  defp act_on({:captions, user_id, on?}, state) do
    with {:ok, _person} <- State.fetch(state.voice, user_id) do
      captions =
        if on?,
          do: MapSet.put(state.captions, user_id),
          else: MapSet.delete(state.captions, user_id)

      {:ok, %{state | captions: captions}}
    end
  end

  defp act_on({:self_mute, user_id, muted?}, state) do
    with {:ok, voice} <- State.self_mute(state.voice, user_id, muted?) do
      save(state, voice, user_id, nil)
    end
  end

  defp act_on({:invite, _actor, user_id}, state) do
    with {:ok, voice} <- State.invite(state.voice, user_id), do: save(state, voice, user_id, nil)
  end

  defp act_on({:demote, actor, user_id}, state) do
    sharing? = state.voice.share == user_id

    with {:ok, voice} <- State.demote(state.voice, user_id),
         {:ok, state} <- save(state, voice, user_id, log(actor, user_id, :moved_to_listeners)) do
      if sharing? and voice.share == nil,
        do: broadcast(%VoiceShareChanged{session_id: state.session.id, user_id: nil})

      {:ok, state}
    end
  end

  defp act_on({:server_mute, actor, user_id, muted?}, state) do
    action = if muted?, do: :server_muted, else: :server_mute_lifted

    with {:ok, voice} <- State.server_mute(state.voice, user_id, muted?) do
      state = speaking(%{state | voice: voice}, user_id, false)
      save(state, voice, user_id, log(actor, user_id, action))
    end
  end

  defp act_on({:disconnect, actor, user_id}, state) do
    with {:ok, _person} <- State.fetch(state.voice, user_id),
         {:ok, row} <- found(Map.fetch(state.rows, user_id)),
         {:ok, _row} <-
           ChangeParticipant.execute(row, %{}, %{
             actor_id: actor,
             action: :disconnected,
             session: state.session
           }) do
      peer = state.peers[user_id]
      state = leave(state, user_id)
      if peer, do: Peer.close(peer, :disconnected)

      {:ok, state}
    end
  end

  defp act_on({:leave, user_id}, state) do
    with {:ok, _person} <- State.fetch(state.voice, user_id) do
      peer = state.peers[user_id]
      state = leave(state, user_id)
      if peer, do: Peer.close(peer, :left)

      {:ok, state}
    end
  end

  defp act_on({:start_share, user_id}, state) do
    with {:ok, voice} <- State.start_share(state.voice, user_id) do
      broadcast(%VoiceShareChanged{session_id: state.session.id, user_id: user_id})
      {:ok, %{state | voice: voice}}
    end
  end

  defp act_on({:stop_share, user_id, moderator?}, state) do
    with true <- moderator? or state.voice.share in [nil, user_id] or {:error, :forbidden},
         {:ok, voice} <- State.stop_share(state.voice) do
      broadcast(%VoiceShareChanged{session_id: state.session.id, user_id: nil})
      {:ok, %{state | voice: voice}}
    end
  end

  defp act_on({:start_recording, actor}, %{recording: nil} = state) do
    with {:ok, recording} <- StartRecording.execute(state.session, actor) do
      Voice.broadcast_recording(recording)
      {:ok, %{state | recording: recording}}
    end
  end

  defp act_on({:start_recording, _actor}, _state), do: {:error, :already_recording}

  defp act_on({:stop_recording, _actor}, %{recording: nil}), do: {:error, :not_recording}

  defp act_on({:stop_recording, actor}, state) do
    recording = state.recording
    state = sync(%{state | recording: nil})

    case Capture.stop(recording, actor, :stopped, Map.values(state.peers)) do
      {:ok, _recording} -> {:ok, state}
      {:error, _reason} -> {:error, :not_recording}
    end
  end

  defp act_on(:end, state) do
    state = stop_recording(state, nil, :ended)
    {:ok, session} = EndSession.execute(state.session)
    close_all(state, :ended)
    broadcast(ended(session, :ended))

    {:stop, state}
  end

  defp act_on(_unknown, _state), do: {:error, :invalid}

  defp found({:ok, _row} = ok), do: ok
  defp found(:error), do: {:error, :not_here}

  defp log(actor, actor, _action), do: nil
  defp log(actor, _user, action), do: %{actor_id: actor, action: action}

  defp save(state, voice, user_id, log) do
    person = voice.people[user_id]
    row = state.rows[user_id]

    changes = %{
      role: person.role,
      hand_raised_at: person.hand_raised_at,
      self_muted: person.self_muted,
      server_muted_at: server_muted_at(row, person),
      server_muted_by_id: server_muted_by(row, person, log)
    }

    log = if log, do: Map.put(log, :session, state.session)

    case ChangeParticipant.execute(row, changes, log) do
      {:ok, row} ->
        state = %{state | voice: voice, rows: Map.put(state.rows, user_id, row)}
        announce(state, user_id)
        {:ok, state}

      {:error, _changeset} ->
        {:error, :invalid}
    end
  end

  defp server_muted_at(_row, %{server_muted: false}), do: nil
  defp server_muted_at(%{server_muted_at: %DateTime{} = at}, %{server_muted: true}), do: at
  defp server_muted_at(_row, %{server_muted: true}), do: DateTime.utc_now()

  defp server_muted_by(_row, %{server_muted: false}, _log), do: nil
  defp server_muted_by(%{server_muted_by_id: by}, %{server_muted: true}, nil), do: by
  defp server_muted_by(_row, %{server_muted: true}, log), do: log.actor_id

  # Ending or losing the session stops its recording, logged as done by whoever started it
  defp stop_recording(%{recording: nil} = state, _actor, _reason), do: state

  defp stop_recording(state, nil, reason) do
    recording = state.recording
    state = sync(%{state | recording: nil})
    actor = recording.started_by_id || state.session.host_id

    case Capture.stop(recording, actor, reason, Map.values(state.peers)) do
      {:ok, _recording} -> :ok
      {:error, reason} -> Logger.error("Voice recording not stopped: #{inspect(reason)}")
    end

    state
  end

  defp speaking(state, user_id, speaking?) do
    may? = speaking? and State.may_speak?(state.voice, user_id) and not muted?(state, user_id)

    set =
      if may?,
        do: MapSet.put(state.speaking, user_id),
        else: MapSet.delete(state.speaking, user_id)

    schedule_speaking(%{state | speaking: set})
  end

  defp muted?(state, user_id) do
    case State.fetch(state.voice, user_id) do
      {:ok, person} -> person.server_muted
      {:error, :not_here} -> true
    end
  end

  defp schedule_speaking(%{speaking_timer: nil} = state) do
    %{state | speaking_timer: Process.send_after(self(), :flush_speaking, @speaking_every)}
  end

  defp schedule_speaking(state), do: state

  defp flush_speaking(%{speaking: same, said: same} = state), do: state

  defp flush_speaking(state) do
    broadcast(%VoiceSpeakingChanged{
      session_id: state.session.id,
      user_ids: state.speaking |> MapSet.to_list() |> Enum.sort()
    })

    %{state | said: state.speaking}
  end

  defp sync(state) do
    routes = State.routes(state.voice)
    record = Capture.route(state.recording)
    caption = MapSet.size(state.captions) > 0

    for {user_id, peer} <- state.peers,
        %{} = route <- [routes[user_id]],
        do: Peer.route(peer, Map.merge(route, %{record: record, caption: caption}))

    watch_empty(state)
  end

  # A session nobody is in ends soon so its room stops showing as live. One started for an
  # event stays until the event's time is up, so people arriving late still find it
  defp watch_empty(%{voice: %{people: people}, empty_timer: nil} = state)
       when map_size(people) == 0,
       do: %{state | empty_timer: Process.send_after(self(), :empty, empty_after(state))}

  defp watch_empty(%{voice: %{people: people}, empty_timer: timer} = state)
       when map_size(people) > 0 and timer != nil do
    Process.cancel_timer(timer)
    %{state | empty_timer: nil}
  end

  defp watch_empty(state), do: state

  defp empty_after(%{event_ends_at: nil}), do: config(:empty_ms)

  defp empty_after(%{event_ends_at: ends_at}),
    do: max(DateTime.diff(ends_at, DateTime.utc_now(), :millisecond), config(:empty_ms))

  defp event_ends_at(%Session{event_id: nil}), do: nil

  defp event_ends_at(%Session{event_id: id, started_at: started_at}) do
    case Events.get_event(id: id) do
      {:ok, event} -> DateTime.add(started_at, event.duration_min, :minute)
      {:error, :not_found} -> nil
    end
  end

  defp attendance(%{session: session, voice: voice}) do
    broadcast(%VoiceAttendance{
      session_id: session.id,
      room_id: session.room_id,
      community_id: session.community_id,
      people: map_size(voice.people),
      user_ids: voice.people |> Map.keys() |> Enum.sort()
    })
  end

  defp announce(state, user_id) do
    {:ok, person} = State.fetch(state.voice, user_id)
    broadcast(participant_event(state.session.id, user_id, person))
  end

  defp participant_event(session_id, user_id, person) do
    %VoiceParticipantChanged{
      session_id: session_id,
      user_id: user_id,
      role: person.role,
      hand_raised_at: person.hand_raised_at,
      self_muted: person.self_muted,
      server_muted: person.server_muted,
      left: false
    }
  end

  defp snapshot_of(state) do
    voice = state.voice

    %{
      session_id: state.session.id,
      mode: voice.mode,
      share: voice.share,
      hands: State.hands(voice),
      speaking: state.speaking |> MapSet.to_list() |> Enum.sort(),
      recording: recording_of(state.recording),
      participants:
        Enum.map(voice.people, fn {id, person} ->
          Map.from_struct(participant_event(state.session.id, id, person))
        end)
    }
  end

  defp recording_of(nil), do: nil

  defp recording_of(%Recording{} = recording) do
    %{
      id: recording.id,
      started_by_id: recording.started_by_id,
      started_at: recording.started_at
    }
  end

  defp close_all(state, reason) do
    for {_user, peer} <- state.peers, do: Peer.close(peer, reason)
    :ok
  end

  # Routes still name a running recording so peers close their files as they stop
  defp lose_session(session) do
    {:ok, session} = EndSession.execute(session)
    peers = RTC.peers(session.id)
    refs = Enum.map(peers, &Process.monitor/1)

    for peer <- peers, do: Peer.close(peer, :lost)
    broadcast(ended(session, :lost))

    with %Recording{} = recording <- Recording.running(session.id) do
      for ref <- refs, do: await_down(ref)
      actor = recording.started_by_id || session.host_id
      Capture.stop(recording, actor, :lost, [])
    end
  end

  defp await_down(ref) do
    receive do
      {:DOWN, ^ref, :process, _pid, _reason} -> :ok
    after
      5_000 -> Process.demonitor(ref, [:flush])
    end
  end

  defp ended(session, reason) do
    %VoiceSessionEnded{
      session_id: session.id,
      room_id: session.room_id,
      community_id: session.community_id,
      post_id: session.post_id,
      reason: reason
    }
  end

  defp broadcast(event), do: PubSub.broadcast(@topic, event)

  defp config(key), do: :hearth |> Application.fetch_env!(Voice) |> Keyword.fetch!(key)
end
