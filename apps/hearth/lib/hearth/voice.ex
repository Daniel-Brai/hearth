defmodule Hearth.Voice do
  events = [
    VoiceAttendance,
    VoiceCaption,
    VoiceParticipantChanged,
    VoiceReaction,
    VoiceRecordingChanged,
    VoiceSessionEnded,
    VoiceSessionStarted,
    VoiceShareChanged,
    VoiceSpeakingChanged
  ]

  default = [
    Listener.Communities,
    Participant,
    Recording,
    Recording.Speaker,
    Session,
    Supervisor | events
  ]

  exports =
    case Mix.env() do
      :test -> [Capture, Captions, Command.StartRecording, Command.StopRecording, Live | default]
      _env -> default
    end

  use Boundary,
    deps: [
      Hearth.Accounts,
      Hearth.AI,
      Hearth.Common,
      Hearth.Communities,
      Hearth.Events,
      Hearth.Forum,
      Hearth.IAM,
      Hearth.Media,
      Hearth.Moderation,
      Hearth.PubSub,
      Hearth.RTC,
      Hearth.Repo,
      Hearth.Roles,
      Hearth.Storage,
      Hearth.TranscriptionPolicy
    ],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.Communities.Room
  alias Hearth.Events.Event
  alias Hearth.Forum.Post
  alias Hearth.IAM
  alias Hearth.PubSub
  alias Hearth.Repo.Page
  alias Hearth.Roles
  alias Hearth.RTC
  alias Hearth.RTC.Peer
  alias Hearth.Storage
  alias Hearth.TranscriptionPolicy
  alias Hearth.Voice.Command.DeleteRecording
  alias Hearth.Voice.Command.EndSession
  alias Hearth.Voice.Command.FailRecording
  alias Hearth.Voice.Live
  alias Hearth.Voice.Participant
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Session
  alias Hearth.Voice.VoiceRecordingChanged
  alias Hearth.Voice.VoiceRecordingDeleted
  alias Hearth.Voice.VoiceRecordingRenamed
  alias Hearth.Voice.VoiceSessionEnded
  alias Hearth.Voice.VoiceSessionStarted

  @topic "voice"

  # A shortcode like the ones the app's emoji picker sends
  @emoji ~r/\A:[a-z0-9_+-]{1,48}:\z/

  @type error ::
          :forbidden
          | :not_found
          | :not_live
          | :unavailable
          | :full
          | :not_here
          | :on_stage
          | :open_mode
          | :not_on_stage
          | :share_taken
          | :not_sharing
          | :same_mode
          | :invalid_transition
          | :invalid_emoji
          | :already_recording
          | :not_recording
          | :still_recording

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec available?() :: boolean()
  def available?, do: RTC.available?()

  @spec get_session(keyword()) :: {:ok, Session.t()} | {:error, :not_found}
  def get_session(opts) when is_list(opts) do
    case Session.get(opts) do
      nil -> {:error, :not_found}
      %Session{} = session -> {:ok, session}
    end
  end

  @spec live_for(User.t()) :: [Session.t()]
  def live_for(%User{} = user) do
    user
    |> IAM.community_ids()
    |> Communities.list_visible_rooms(:voice, user)
    |> Enum.map(& &1.id)
    |> Session.live_in_rooms()
  end

  @spec people_in(Session.t()) :: non_neg_integer()
  def people_in(%Session{id: id}), do: Participant.count_present(id)

  @spec start_session(User.t(), Room.t(), map()) ::
          {:ok, Session.t()}
          | {:error, :forbidden | :not_found | :unavailable | Changeset.t()}
          | {:error, :already_live, Session.t()}
  def start_session(%User{} = user, %Room{} = room, %{} = params \\ %{}) do
    with :ok <- voice_room(room),
         :ok <- may_read(user, room),
         :ok <- allowed(user, :create, room.community_id) do
      start(room, user.id, params)
    end
  end

  @spec start_for_event(Event.t()) :: {:ok, nil | Session.t()} | {:error, term()}
  def start_for_event(%Event{room_id: nil}), do: {:ok, nil}

  def start_for_event(%Event{} = event) do
    params = %{mode: event.talk_mode || :stage, topic: event.title, event_id: event.id}

    with {:ok, room} <- Communities.get_room(id: event.room_id),
         :ok <- voice_room(room) do
      case start(room, event.host_id, params) do
        {:error, :already_live, _session} -> {:ok, nil}
        result -> result
      end
    end
  end

  @spec discuss_live(User.t(), Post.t()) ::
          {:ok, Session.t()}
          | {:error, :forbidden | :no_voice_room | :rooms_busy | :unavailable | Changeset.t()}
          | {:error, :already_live, Session.t()}
  def discuss_live(%User{id: id} = user, %Post{author_id: id, status: :published} = post) do
    with :ok <- may_enter(user, post.community_id),
         :ok <- allowed(user, :create, post.community_id),
         nil <- Session.get(post_id: post.id, ended_at: nil),
         {:ok, room} <- free_room(post.community_id) do
      start(room, id, %{mode: :stage, topic: post.title, post_id: post.id})
    else
      %Session{} = session -> {:error, :already_live, session}
      error -> error
    end
  end

  def discuss_live(%User{}, %Post{}), do: {:error, :forbidden}

  @spec live_on_posts([T.id()]) :: %{T.id() => Session.t()}
  def live_on_posts(post_ids) when is_list(post_ids),
    do: post_ids |> Session.live_on_posts() |> Map.new(&{&1.post_id, &1})

  # A post is for everyone in the community, so it is never discussed in a private room
  defp free_room(community_id) do
    {:ok, community} = Communities.get_community(id: community_id)

    rooms =
      community
      |> Communities.list_rooms()
      |> Enum.filter(&(&1.type == :voice and &1.access == :everyone))

    live = rooms |> Enum.map(& &1.id) |> Session.live_in_rooms() |> MapSet.new(& &1.room_id)

    case {rooms, Enum.reject(rooms, &MapSet.member?(live, &1.id))} do
      {[], _free} -> {:error, :no_voice_room}
      {_rooms, []} -> {:error, :rooms_busy}
      {_rooms, [room | _rest]} -> {:ok, room}
    end
  end

  # Starting reaches across nodes to run the session, so it gets its own span
  defp start(room, host_id, params) do
    Common.span("voice.start_session", %{room_id: room.id}, fn ->
      start_on_node(room, host_id, params)
    end)
  end

  defp start_on_node(room, host_id, params) do
    session = %Session{room_id: room.id, community_id: room.community_id, host_id: host_id}

    with {:ok, node} <- pick_node(),
         {:ok, session} <- insert(%{session | node: Atom.to_string(node)}, params, room.id),
         {:ok, _live} <- run(session) do
      broadcast(%VoiceSessionStarted{
        session_id: session.id,
        room_id: session.room_id,
        community_id: session.community_id,
        host_id: session.host_id,
        mode: session.mode,
        topic: session.topic,
        post_id: session.post_id
      })

      {:ok, session}
    end
  end

  defp insert(session, params, room_id) do
    case Session.insert(session, params) do
      {:ok, session} ->
        {:ok, session}

      {:error, %Changeset{errors: errors} = changeset} ->
        with true <- Keyword.has_key?(errors, :room_id),
             %Session{} = live <- Session.live_in(room_id) do
          {:error, :already_live, live}
        else
          _other -> {:error, changeset}
        end
    end
  end

  defp pick_node do
    case RTC.pick_node() do
      nil -> {:error, :unavailable}
      node -> {:ok, node}
    end
  end

  # A session whose process can't start ends at once so the room isn't left looking live
  defp run(session) do
    node = String.to_existing_atom(session.node)

    case :erpc.call(node, __MODULE__, :start_live, [session.id], 15_000) do
      {:ok, pid} when is_pid(pid) ->
        {:ok, pid}

      _failed ->
        {:ok, _session} = EndSession.execute(session)
        {:error, :unavailable}
    end
  catch
    :error, {:erpc, _reason} ->
      {:ok, _session} = EndSession.execute(session)
      {:error, :unavailable}
  end

  @doc false
  @spec start_live(T.id()) :: DynamicSupervisor.on_start_child()
  def start_live(session_id) do
    DynamicSupervisor.start_child(Hearth.Voice.LiveSupervisor, {Live, session_id})
  end

  @spec end_session(User.t(), Session.t()) :: :ok | {:error, error()}
  def end_session(%User{} = user, %Session{} = session) do
    with :ok <- host_tools(user, session), do: act(session, :end)
  end

  @spec end_orphans() :: non_neg_integer()
  def end_orphans do
    orphans = Enum.filter(Session.live(), &(Live.whereis(&1.id) == nil))

    for session <- orphans do
      {:ok, session} = EndSession.execute(session)

      with %Recording{} = recording <- Recording.running(session.id),
           do: FailRecording.execute(recording, "The recording was lost when its server stopped.")

      broadcast(%VoiceSessionEnded{
        session_id: session.id,
        room_id: session.room_id,
        community_id: session.community_id,
        post_id: session.post_id,
        reason: :lost
      })
    end

    length(orphans)
  end

  @spec join(User.t(), Session.t(), pid(), keyword()) ::
          {:ok, %{peer: pid(), snapshot: map(), ice_servers: [RTC.Turn.ice_server()]}}
          | {:error, error()}
  def join(%User{} = user, %Session{} = session, channel, opts \\ []) when is_pid(channel) do
    may_speak? = session.host_id == user.id or can?(user, :speak, session)

    Common.span("voice.join", %{session_id: session.id}, fn ->
      with :ok <- may_see(user, session),
           {:ok, live} <- live(session),
           {:ok, joined} <-
             Live.join(live, user.id, channel, Keyword.get(opts, :stage, true), may_speak?) do
        {:ok, Map.put(joined, :ice_servers, RTC.ice_servers(user.id))}
      end
    end)
  end

  @spec answer(pid(), String.t()) :: :ok | {:error, term()}
  def answer(peer, sdp) when is_pid(peer) and is_binary(sdp), do: Peer.answer(peer, sdp)

  @spec candidate(pid(), nil | map()) :: :ok
  def candidate(peer, candidate) when is_pid(peer), do: Peer.candidate(peer, candidate)

  @spec ice_restart(User.t(), pid()) :: [RTC.Turn.ice_server()]
  def ice_restart(%User{id: id}, peer) when is_pid(peer) do
    :ok = Peer.ice_restart(peer)
    RTC.ice_servers(id)
  end

  @spec snapshot(User.t(), Session.t()) :: {:ok, map()} | {:error, error()}
  def snapshot(%User{} = user, %Session{} = session) do
    with :ok <- may_see(user, session),
         {:ok, live} <- live(session) do
      {:ok, Live.snapshot(live)}
    end
  end

  @spec leave(User.t(), Session.t()) :: :ok | {:error, error()}
  def leave(%User{id: id}, %Session{} = session), do: act(session, {:leave, id})

  # Captions run on the server's Whisper, so they need transcription on
  @spec captions(User.t(), Session.t(), boolean()) :: :ok | {:error, error() | :transcription_off}
  def captions(%User{id: id}, %Session{} = session, on?) when is_boolean(on?) do
    with :ok <- TranscriptionPolicy.check(), do: act(session, {:captions, id, on?})
  end

  @spec raise_hand(User.t(), Session.t(), boolean()) :: :ok | {:error, error()}
  def raise_hand(%User{id: id}, %Session{} = session, true), do: act(session, {:raise_hand, id})
  def raise_hand(%User{id: id}, %Session{} = session, false), do: act(session, {:lower_hand, id})

  # The browser stops sending on its own, this only tells the room
  @spec self_mute(User.t(), Session.t(), boolean()) :: :ok | {:error, error()}
  def self_mute(%User{id: id}, %Session{} = session, muted?) when is_boolean(muted?),
    do: act(session, {:self_mute, id, muted?})

  # Anyone there may react, muted or not since a reaction makes no sound
  @spec react(User.t(), Session.t(), String.t()) :: :ok | {:error, error()}
  def react(%User{id: id}, %Session{} = session, emoji) when is_binary(emoji) do
    if Regex.match?(@emoji, emoji),
      do: act(session, {:react, id, emoji}),
      else: {:error, :invalid_emoji}
  end

  @spec start_share(User.t(), Session.t()) :: :ok | {:error, error()}
  def start_share(%User{id: id}, %Session{} = session), do: act(session, {:start_share, id})

  @spec stop_share(User.t(), Session.t()) :: :ok | {:error, error()}
  def stop_share(%User{} = user, %Session{} = session) do
    act(session, {:stop_share, user.id, host_tools(user, session) == :ok})
  end

  @spec invite(User.t(), Session.t(), T.id()) :: :ok | {:error, error()}
  def invite(%User{} = user, %Session{} = session, user_id) do
    with :ok <- host_tools(user, session), do: act(session, {:invite, user.id, user_id})
  end

  @spec demote(User.t(), Session.t(), T.id()) :: :ok | {:error, error()}
  def demote(%User{id: id}, %Session{} = session, id), do: act(session, {:demote, id, id})

  def demote(%User{} = user, %Session{} = session, user_id) do
    with :ok <- host_tools(user, session), do: act(session, {:demote, user.id, user_id})
  end

  # Their audio is dropped on the server whatever their browser sends
  @spec server_mute(User.t(), Session.t(), T.id(), boolean()) :: :ok | {:error, error()}
  def server_mute(%User{} = user, %Session{} = session, user_id, muted?)
      when is_boolean(muted?) do
    with :ok <- host_tools(user, session),
         do: act(session, {:server_mute, user.id, user_id, muted?})
  end

  @spec disconnect(User.t(), Session.t(), T.id()) :: :ok | {:error, error()}
  def disconnect(%User{} = user, %Session{} = session, user_id) do
    with :ok <- host_tools(user, session), do: act(session, {:disconnect, user.id, user_id})
  end

  # Every node runs the same release so finding ffmpeg here finds it there
  @spec recording_available?() :: boolean()
  def recording_available? do
    available?() and :media in Roles.in_cluster() and System.find_executable("ffmpeg") != nil
  end

  @spec start_recording(User.t(), Session.t()) :: :ok | {:error, error()}
  def start_recording(%User{} = user, %Session{} = session) do
    with :ok <- may_record(user, session), do: act(session, {:start_recording, user.id})
  end

  @spec stop_recording(User.t(), Session.t()) :: :ok | {:error, error()}
  def stop_recording(%User{} = user, %Session{} = session) do
    with :ok <- may_record(user, session), do: act(session, {:stop_recording, user.id})
  end

  @spec recording?(Session.t()) :: boolean()
  def recording?(%Session{} = session), do: Recording.running(session.id) != nil

  @spec may_record?(User.t(), Session.t()) :: boolean()
  def may_record?(%User{} = user, %Session{} = session), do: may_record(user, session) == :ok

  # Failed recordings are listed only for people who may record there
  @spec list_recordings(User.t(), Recording.scope()) ::
          {:ok, [Recording.t()]} | {:error, :forbidden | :not_found}
  def list_recordings(%User{} = user, {_field, _id, community_id} = scope) do
    with :ok <- may_enter(user, community_id) do
      failed? = IAM.can?(user, :create, %{type: :"voice.recording", community_id: community_id})
      seen = [community_id] |> Communities.list_visible_rooms(:voice, user) |> MapSet.new(& &1.id)

      {:ok, scope |> Recording.list(failed?) |> Enum.filter(&MapSet.member?(seen, &1.room_id))}
    end
  end

  # A room can gather many recordings, so its list comes a page at a time, newest first
  @spec list_room_recordings(User.t(), Room.t(), keyword()) ::
          {:ok, Page.t()} | {:error, error() | Flop.Meta.t()}
  def list_room_recordings(%User{} = user, %Room{} = room, paging) when is_list(paging) do
    with :ok <- may_read(user, room) do
      failed? =
        IAM.can?(user, :create, %{type: :"voice.recording", community_id: room.community_id})

      paging
      |> Keyword.merge(
        room_id: room.id,
        community_id: room.community_id,
        status: Recording.shown(failed?)
      )
      |> Recording.paginate()
      |> paged()
    end
  end

  defp paged(%Page{} = page), do: {:ok, page}
  defp paged({:error, _meta} = error), do: error

  @spec get_recording(keyword()) :: {:ok, Recording.t()} | {:error, :not_found}
  def get_recording(opts) when is_list(opts) do
    case Recording.get(opts) do
      nil -> {:error, :not_found}
      %Recording{} = recording -> {:ok, recording}
    end
  end

  @spec get_recording(User.t(), T.id()) :: {:ok, Recording.t()} | {:error, error()}
  def get_recording(%User{} = user, id) do
    with %Recording{} = recording <- Recording.get(id: id),
         {:ok, room} <- Communities.get_room(id: recording.room_id),
         :ok <- may_read(user, room) do
      {:ok, recording}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  # Only the person who started a recording may delete it, once it has stopped
  @spec delete_recording(User.t(), T.id()) :: {:ok, Recording.t()} | {:error, error()}
  def delete_recording(%User{id: user_id} = user, id) do
    case get_recording(user, id) do
      {:ok, %Recording{started_by_id: ^user_id} = recording} -> DeleteRecording.execute(recording)
      {:ok, %Recording{}} -> {:error, :forbidden}
      error -> error
    end
  end

  # Only the person who started a recording may rename it
  @spec rename_recording(User.t(), T.id(), String.t()) ::
          {:ok, Recording.t()} | {:error, error() | Changeset.t()}
  def rename_recording(%User{id: user_id} = user, id, title) do
    with {:ok, %Recording{started_by_id: ^user_id} = recording} <- get_recording(user, id),
         {:ok, renamed} <- Recording.rename(recording, title) do
      broadcast_renamed(renamed)
      {:ok, renamed}
    else
      {:ok, %Recording{}} -> {:error, :forbidden}
      error -> error
    end
  end

  @spec recording_urls(Recording.t()) :: %{
          video: nil | String.t(),
          download: nil | String.t(),
          poster: nil | String.t(),
          speakers: %{T.id() => String.t()}
        }
  def recording_urls(%Recording{status: :ready} = recording) do
    %{
      video: signed(recording.video_key),
      download: download(recording),
      poster: signed(recording.poster_key),
      speakers: Map.new(recording.speakers, &{&1.user_id, signed(&1.key)})
    }
  end

  def recording_urls(%Recording{}), do: %{video: nil, download: nil, poster: nil, speakers: %{}}

  defp download(%Recording{video_key: nil}), do: nil

  defp download(%Recording{video_key: key, started_at: started_at}) do
    {:ok, url} =
      Storage.download_url(
        key,
        "Recording #{Calendar.strftime(started_at, "%Y-%m-%d %H-%M")}.mp4"
      )

    url
  end

  defp signed(nil), do: nil

  defp signed(key) do
    {:ok, url} = Storage.get_url(key)
    url
  end

  @doc false
  @spec broadcast_recording(Recording.t()) :: :ok
  def broadcast_recording(%Recording{} = recording) do
    %Session{post_id: post_id} = Session.get(id: recording.session_id)

    broadcast(%VoiceRecordingChanged{
      session_id: recording.session_id,
      post_id: post_id,
      community_id: recording.community_id,
      room_id: recording.room_id,
      recording_id: recording.id,
      status: recording.status,
      started_by_id: recording.started_by_id,
      started_at: recording.started_at
    })
  end

  @spec broadcast_deleted(Recording.t()) :: :ok
  def broadcast_deleted(%Recording{} = recording) do
    %Session{post_id: post_id} = Session.get(id: recording.session_id)

    broadcast(%VoiceRecordingDeleted{
      recording_id: recording.id,
      session_id: recording.session_id,
      post_id: post_id,
      community_id: recording.community_id,
      room_id: recording.room_id
    })
  end

  defp broadcast_renamed(%Recording{} = recording) do
    %Session{post_id: post_id} = Session.get(id: recording.session_id)

    broadcast(%VoiceRecordingRenamed{
      recording_id: recording.id,
      title: recording.title,
      session_id: recording.session_id,
      post_id: post_id,
      community_id: recording.community_id,
      room_id: recording.room_id
    })
  end

  # Each node handles the sessions it runs
  @spec remove_hidden(T.id(), nil | T.id(), nil | T.id()) :: :ok
  def remove_hidden(community_id, nil, user_id),
    do: remove_hidden_in([community_id: community_id, ended_at: nil], user_id)

  def remove_hidden(community_id, room_id, user_id),
    do: remove_hidden_in([community_id: community_id, room_id: room_id, ended_at: nil], user_id)

  @spec host_tools?(User.t(), Session.t()) :: boolean()
  def host_tools?(%User{} = user, %Session{} = session), do: host_tools(user, session) == :ok

  defp act(session, action) do
    with {:ok, live} <- live(session), do: Live.act(live, action)
  end

  defp live(%Session{ended_at: nil} = session) do
    case Live.whereis(session.id) do
      nil -> {:error, :not_live}
      pid -> {:ok, pid}
    end
  end

  defp live(%Session{}), do: {:error, :not_live}

  defp remove_hidden_in(filters, user_id) do
    filters
    |> Session.all()
    |> Enum.each(&remove_hidden_from(&1, user_id))
  end

  defp remove_hidden_from(session, user_id) do
    with {:ok, live} <- local_live(session),
         {:ok, room} <- Communities.get_room(id: session.room_id) do
      session.id
      |> Participant.present()
      |> Enum.filter(&(user_id in [nil, &1.user_id] and not sees_room?(&1.user_id, room)))
      |> Enum.each(&Live.act(live, {:remove, &1.user_id}))
    end
  end

  defp local_live(session) do
    case live(session) do
      {:ok, pid} when node(pid) == node() -> {:ok, pid}
      _elsewhere -> {:error, :not_live}
    end
  end

  defp sees_room?(user_id, room) do
    case Accounts.get_user(id: user_id) do
      {:ok, user} -> Communities.room_visible?(user, room)
      {:error, :not_found} -> false
    end
  end

  defp voice_room(%Room{type: :voice, archived_at: nil}), do: :ok
  defp voice_room(%Room{}), do: {:error, :not_found}

  defp may_read(user, %Room{} = room) do
    with :ok <- may_enter(user, room.community_id) do
      case Communities.room_visible?(user, room) do
        true -> :ok
        false -> {:error, :not_found}
      end
    end
  end

  defp may_see(user, %Session{room_id: room_id}) do
    with {:ok, room} <- Communities.get_room(id: room_id), do: may_read(user, room)
  end

  defp may_enter(user, community_id) do
    case IAM.member?(user, community_id) and not Communities.banned?(user, community_id) do
      true -> :ok
      false -> Communities.refusal(user, community_id)
    end
  end

  defp host_tools(%User{id: id}, %Session{host_id: id}), do: :ok

  defp host_tools(user, session) do
    case IAM.can?(user, :remove, %{type: :content, community_id: session.community_id}) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp may_record(%User{id: id}, %Session{host_id: id}), do: :ok

  defp may_record(user, session) do
    case IAM.can?(user, :create, %{type: :"voice.recording", community_id: session.community_id}) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp allowed(user, action, community_id) do
    case IAM.can?(user, action, %{type: :"voice.session", community_id: community_id}) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp can?(user, action, session) do
    IAM.can?(user, action, %{type: :"voice.session", community_id: session.community_id})
  end

  defp broadcast(event), do: PubSub.broadcast(@topic, event)
end
