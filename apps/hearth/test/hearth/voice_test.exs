defmodule Hearth.VoiceTest do
  use Hearth.DataCase, async: false

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Moderation.Action
  alias Hearth.Storage
  alias Hearth.TestUtils
  alias Hearth.Voice
  alias Hearth.Voice.Live
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Recording.Track
  alias Hearth.Voice.Session
  alias Hearth.Voice.VoiceAttendance
  alias Hearth.Voice.VoiceParticipantChanged
  alias Hearth.Voice.VoiceRecordingChanged
  alias Hearth.Voice.VoiceRecordingDeleted
  alias Hearth.Voice.VoiceRecordingRenamed
  alias Hearth.Voice.VoiceSessionEnded
  alias Hearth.Voice.VoiceSessionStarted
  alias Hearth.Voice.VoiceShareChanged
  alias Hearth.Voice.VoiceSpeakingChanged
  alias Hearth.Voice.Worker.AssembleRecording

  setup do
    :ok = TestUtils.start_voice!()
    :ok = Voice.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    moderator = TestUtils.join_with_permissions!(community, ["content.remove"])
    speaker = TestUtils.join_with_permissions!(community, ["voice-session.speak"])
    recorder = TestUtils.join_with_permissions!(community, ["voice-recording.create"])
    room = TestUtils.create_random_voice_room!(community)

    {:ok, binding()}
  end

  describe "start_session/3" do
    test "fails if not allowed", %{member: member, room: room} do
      assert {:error, :forbidden} = Voice.start_session(member, room, %{})
    end

    test "fails for a text room", %{owner: owner, community: community} do
      room = TestUtils.get_room!(community, type: :text)

      assert {:error, :not_found} = Voice.start_session(owner, room, %{})
    end

    test "fails without an rtc node", %{owner: owner, room: room} do
      :ok = TestUtils.stop_rtc!()

      assert {:error, :unavailable} = Voice.start_session(owner, room, %{})
    end

    test "start session", %{owner: owner, room: room} do
      %{id: host_id} = owner
      node = Atom.to_string(node())

      assert {:ok, %Session{id: id, host_id: ^host_id, node: ^node, mode: :open}} =
               Voice.start_session(owner, room, %{"mode" => "open", "topic" => "Release"})

      assert is_pid(TestUtils.live_of!(%Session{id: id}))
      assert_receive %VoiceSessionStarted{session_id: ^id, host_id: ^host_id, topic: "Release"}
    end

    test "gives the live session of a live room", %{owner: owner, room: room} do
      {:ok, %Session{id: id}} = Voice.start_session(owner, room, %{})

      assert {:error, :already_live, %Session{id: ^id}} = Voice.start_session(owner, room, %{})
    end
  end

  describe "discuss_live/2" do
    setup %{owner: owner} do
      forum = TestUtils.create_random_forum!(owner, template: "blank")
      post = TestUtils.create_random_post!(owner, forum)

      {:ok, binding()}
    end

    test "fails for someone who didn't write the post", %{forum: forum, post: post} do
      _room = TestUtils.create_random_voice_room!(forum)
      moderator = TestUtils.join_with_permissions!(forum, ["voice-session.create"])

      assert {:error, :forbidden} = Voice.discuss_live(moderator, post)
    end

    test "fails without a voice room", %{owner: owner, post: post} do
      assert {:error, :no_voice_room} = Voice.discuss_live(owner, post)
    end

    test "fails when every voice room is live", %{owner: owner, forum: forum, post: post} do
      room = TestUtils.create_random_voice_room!(forum)
      {:ok, _session} = Voice.start_session(owner, room, %{})

      assert {:error, :rooms_busy} = Voice.discuss_live(owner, post)
    end

    test "discuss live", %{owner: owner, forum: forum, post: post} do
      %{id: post_id, title: title} = post
      _room = TestUtils.create_random_voice_room!(forum)

      assert {:ok, %Session{id: id, post_id: ^post_id, topic: ^title, mode: :stage}} =
               Voice.discuss_live(owner, post)

      assert_receive %VoiceSessionStarted{session_id: ^id, post_id: ^post_id}
    end

    test "gives the post's session while it is live", %{owner: owner, forum: forum, post: post} do
      _room = TestUtils.create_random_voice_room!(forum)
      _other = TestUtils.create_random_voice_room!(forum)
      {:ok, %Session{id: id}} = Voice.discuss_live(owner, post)

      assert {:error, :already_live, %Session{id: ^id}} = Voice.discuss_live(owner, post)
    end
  end

  describe "live_on_posts/1" do
    test "maps each live post to its session", %{owner: owner} do
      forum = TestUtils.create_random_forum!(owner, template: "blank")
      _room = TestUtils.create_random_voice_room!(forum)
      live = TestUtils.create_random_post!(owner, forum)
      quiet = TestUtils.create_random_post!(owner, forum)
      {:ok, %Session{id: id}} = Voice.discuss_live(owner, live)

      assert %{} = sessions = Voice.live_on_posts([live.id, quiet.id])
      assert [live.id] == Map.keys(sessions)
      assert %Session{id: ^id} = sessions[live.id]
    end
  end

  describe "join/4" do
    test "fails for someone outside the community", %{community: community} do
      session = TestUtils.start_random_voice_session!(community)
      stranger = TestUtils.register_random_user!()

      assert {:error, :forbidden} =
               Voice.join(stranger, session, TestUtils.start_fake_channel!())
    end

    test "fails for an ended session", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.end_session(owner, session)
      {:ok, ended} = Voice.get_session(id: session.id)

      assert {:error, :not_live} = Voice.join(owner, ended, TestUtils.start_fake_channel!())
    end

    test "fails when full", %{owner: owner, member: member, community: community} do
      TestUtils.put_voice(room_limit: 1)
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())

      assert {:error, :full} = Voice.join(member, session, TestUtils.start_fake_channel!())
    end

    test "joins", %{owner: owner, member: member, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: owner_id} = owner
      %{id: member_id} = member
      %{id: speaker_id} = speaker
      channel = TestUtils.start_fake_channel!()

      assert {:ok, %{peer: peer, ice_servers: [], snapshot: %{mode: :stage}}} =
               Voice.join(owner, session, channel)

      assert is_pid(peer)

      assert_receive {:voice_channel, ^channel, {:hearth_rtc, :offer, %{sdp: "v=0" <> _sdp}}},
                     1_000

      assert {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert {:ok, %{snapshot: snapshot}} =
               Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert [
               %{user_id: ^owner_id, role: :host},
               %{user_id: ^member_id, role: :listener},
               %{user_id: ^speaker_id, role: :speaker}
             ] = snapshot.participants

      assert_receive %VoiceParticipantChanged{user_id: ^member_id, role: :listener, left: false}
      session_id = session.id
      assert_receive %VoiceAttendance{session_id: ^session_id, people: 3, user_ids: [_, _, _]}
    end

    test "keeps a dropped person's place for the grace", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: member_id} = member
      channel = TestUtils.start_fake_channel!()
      {:ok, _joined} = Voice.join(member, session, channel)
      :ok = Voice.raise_hand(member, session, true)

      send(channel, :stop)
      {:ok, %{snapshot: snapshot}} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert [^member_id] = snapshot.hands
    end

    test "lets a dropped person go after the grace", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: member_id} = member
      channel = TestUtils.start_fake_channel!()
      {:ok, _joined} = Voice.join(member, session, channel)

      send(channel, :stop)

      assert_receive %VoiceParticipantChanged{user_id: ^member_id, left: true}, 1_000
      session_id = session.id
      assert_receive %VoiceAttendance{session_id: ^session_id, people: 0, user_ids: []}
    end
  end

  describe "an empty session" do
    setup do
      TestUtils.put_voice(empty_ms: 200)
    end

    test "ends once nobody has been in it for a while", %{
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)
      %{id: id} = session
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())
      live = TestUtils.live_of!(session)
      ref = Process.monitor(live)

      :ok = Voice.leave(member, session)

      assert_receive %VoiceSessionEnded{session_id: ^id, reason: :ended}, 1_000
      assert_receive {:DOWN, ^ref, :process, ^live, :normal}
      assert %Session{ended_at: %DateTime{}} = Session.get(id: id)
    end

    test "stays live during its event", %{
      owner: owner,
      member: member,
      community: community
    } do
      event = TestUtils.create_random_community_event!(owner, community)
      {:ok, %Session{id: id} = session} = Voice.start_for_event(event)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      :ok = Voice.leave(member, session)

      refute_receive %VoiceSessionEnded{session_id: ^id}, 500
    end

    test "stays live while someone is in it", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: id} = session
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      refute_receive %VoiceSessionEnded{session_id: ^id}, 500
    end
  end

  describe "leave/2" do
    test "fails for someone not here", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert {:error, :not_here} = Voice.leave(member, session)
    end

    test "leave", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: member_id} = member
      channel = TestUtils.start_fake_channel!()
      {:ok, _joined} = Voice.join(member, session, channel)

      assert :ok = Voice.leave(member, session)
      assert_receive %VoiceParticipantChanged{user_id: ^member_id, left: true}
      assert_receive {:voice_channel, ^channel, {:hearth_rtc, :closed, :left}}, 1_000
    end
  end

  describe "react/3" do
    test "fails for something that isn't an emoji", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert {:error, :invalid_emoji} = Voice.react(member, session, "<b>hi</b>")
    end

    test "fails for someone not here", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert {:error, :not_here} = Voice.react(member, session, ":tada:")
    end
  end

  describe "captions/3" do
    test "fails where speech isn't turned into text", %{member: member, community: community} do
      TestUtils.put_transcription(:off)
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert {:error, :transcription_off} = Voice.captions(member, session, true)
    end

    test "fails for someone not here", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert {:error, :not_here} = Voice.captions(member, session, true)
    end

    test "turns captions on and off", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert :ok = Voice.captions(member, session, true)
      assert :ok = Voice.captions(member, session, false)
    end
  end

  describe "raise_hand/3" do
    test "fails on stage", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())

      assert {:error, :on_stage} = Voice.raise_hand(owner, session, true)
    end

    test "fails for someone not here", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert {:error, :not_here} = Voice.raise_hand(member, session, true)
    end

    test "raise hand", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: member_id} = member
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert :ok = Voice.raise_hand(member, session, true)
      assert_receive %VoiceParticipantChanged{user_id: ^member_id, hand_raised_at: %DateTime{}}

      assert :ok = Voice.raise_hand(member, session, false)
      assert_receive %VoiceParticipantChanged{user_id: ^member_id, hand_raised_at: nil}
    end
  end

  describe "self_mute/3" do
    test "self mute", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: owner_id} = owner
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())

      assert :ok = Voice.self_mute(owner, session, false)
      assert_receive %VoiceParticipantChanged{user_id: ^owner_id, self_muted: false}
    end
  end

  describe "invite/3" do
    test "fails without host tools", %{member: member, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert {:error, :forbidden} = Voice.invite(speaker, session, member.id)
    end

    test "fails for a speaker", %{owner: owner, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert {:error, :invalid_transition} = Voice.invite(owner, session, speaker.id)
    end

    test "invite", %{moderator: moderator, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: member_id} = member
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert :ok = Voice.invite(moderator, session, member_id)
      assert_receive %VoiceParticipantChanged{user_id: ^member_id, role: :speaker}
    end
  end

  describe "demote/3" do
    test "fails without host tools", %{member: member, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert {:error, :forbidden} = Voice.demote(member, session, speaker.id)
    end

    test "steps down", %{speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: speaker_id} = speaker
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert :ok = Voice.demote(speaker, session, speaker_id)
      assert_receive %VoiceParticipantChanged{user_id: ^speaker_id, role: :listener}
      refute Action.exists?(target_id: speaker_id)
    end

    test "demote", %{owner: owner, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: speaker_id} = speaker
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert :ok = Voice.demote(owner, session, speaker_id)
      assert_receive %VoiceParticipantChanged{user_id: ^speaker_id, role: :listener}

      assert Action.exists?(
               actor_id: owner.id,
               target_id: speaker_id,
               action: :moved_to_listeners,
               subject_type: :room,
               subject_id: session.room_id
             )
    end
  end

  describe "server_mute/4" do
    test "fails without host tools", %{member: member, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert {:error, :forbidden} = Voice.server_mute(member, session, speaker.id, true)
    end

    test "server mute", %{moderator: moderator, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: speaker_id} = speaker
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert :ok = Voice.server_mute(moderator, session, speaker_id, true)
      assert_receive %VoiceParticipantChanged{user_id: ^speaker_id, server_muted: true}
      assert Action.exists?(target_id: speaker_id, action: :server_muted)

      assert :ok = Voice.server_mute(moderator, session, speaker_id, false)
      assert_receive %VoiceParticipantChanged{user_id: ^speaker_id, server_muted: false}
      assert Action.exists?(target_id: speaker_id, action: :server_mute_lifted)
    end
  end

  describe "disconnect/3" do
    test "fails without host tools", %{member: member, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert {:error, :forbidden} = Voice.disconnect(member, session, speaker.id)
    end

    test "fails for someone not here", %{owner: owner, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert {:error, :not_here} = Voice.disconnect(owner, session, member.id)
    end

    test "disconnect", %{owner: owner, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: member_id} = member
      channel = TestUtils.start_fake_channel!()
      {:ok, _joined} = Voice.join(member, session, channel)

      assert :ok = Voice.disconnect(owner, session, member_id)
      assert_receive {:voice_channel, ^channel, {:hearth_rtc, :closed, :disconnected}}, 1_000
      assert_receive %VoiceParticipantChanged{user_id: ^member_id, left: true}
      assert Action.exists?(target_id: member_id, action: :disconnected)
    end
  end

  describe "start_share/2" do
    test "fails off stage", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert {:error, :not_on_stage} = Voice.start_share(member, session)
    end

    test "fails while someone shares", %{owner: owner, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())
      :ok = Voice.start_share(owner, session)

      assert {:error, :share_taken} = Voice.start_share(speaker, session)
    end

    test "start share", %{speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: speaker_id} = speaker
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())

      assert :ok = Voice.start_share(speaker, session)
      assert_receive %VoiceShareChanged{user_id: ^speaker_id}
    end
  end

  describe "stop_share/2" do
    test "fails for someone else's share", %{
      member: member,
      speaker: speaker,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())
      :ok = Voice.start_share(speaker, session)

      assert {:error, :forbidden} = Voice.stop_share(member, session)
    end

    test "stop share", %{moderator: moderator, speaker: speaker, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())
      :ok = Voice.start_share(speaker, session)

      assert :ok = Voice.stop_share(moderator, session)
      assert_receive %VoiceShareChanged{user_id: nil}
    end
  end

  describe "start_recording/2" do
    test "fails without voice-recording.create", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert {:error, :forbidden} = Voice.start_recording(member, session)
    end

    test "fails while one runs", %{owner: owner, recorder: recorder, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.start_recording(owner, session)

      assert {:error, :already_recording} = Voice.start_recording(recorder, session)
    end

    test "fails after the session ended", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.end_session(owner, session)
      {:ok, ended} = Voice.get_session(id: session.id)

      assert {:error, :not_live} = Voice.start_recording(owner, ended)
    end

    test "start recording", %{recorder: recorder, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: id} = session
      %{id: recorder_id} = recorder

      assert :ok = Voice.start_recording(recorder, session)

      assert_receive %VoiceRecordingChanged{
        session_id: ^id,
        status: :recording,
        started_by_id: ^recorder_id
      }

      assert %{recording: %{started_by_id: ^recorder_id}} =
               id |> Live.whereis() |> Live.snapshot()

      assert Action.exists?(actor_id: recorder_id, action: :recording_started)
    end

    test "name it after the session's event", %{owner: owner, community: community} do
      event = TestUtils.create_random_community_event!(owner, community)
      {:ok, session} = Voice.start_for_event(event)

      assert :ok = Voice.start_recording(owner, session)
      assert %Recording{title: title} = Recording.running(session.id)
      assert title == event.title
    end

    test "name it after the event happening in the room", %{owner: owner, community: community} do
      event =
        TestUtils.create_random_community_event!(owner, community, starts_at: DateTime.utc_now())

      {:ok, room} = Communities.get_room(id: event.room_id)
      {:ok, session} = Voice.start_session(owner, room)

      assert :ok = Voice.start_recording(owner, session)
      assert %Recording{title: title} = Recording.running(session.id)
      assert title == event.title
    end
  end

  describe "stop_recording/2" do
    test "fails without voice-recording.create", %{
      owner: owner,
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.start_recording(owner, session)

      assert {:error, :forbidden} = Voice.stop_recording(member, session)
    end

    test "fails when nothing records", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert {:error, :not_recording} = Voice.stop_recording(owner, session)
    end

    test "fails a recording with nothing in it", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.start_recording(owner, session)

      assert :ok = Voice.stop_recording(owner, session)
      :ok = TestUtils.await_recording_uploads!()

      assert_receive %VoiceRecordingChanged{status: :failed}
    end

    test "stop recording", %{owner: owner, recorder: recorder, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: owner_id} = owner
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())
      :ok = Voice.start_recording(recorder, session)
      :ok = TestUtils.send_random_audio!(session, owner_id)

      assert :ok = Voice.stop_recording(recorder, session)
      :ok = TestUtils.await_recording_uploads!()

      assert_receive %VoiceRecordingChanged{status: :processing, recording_id: id}
      assert %{recording: nil} = session.id |> Live.whereis() |> Live.snapshot()
      assert Action.exists?(actor_id: recorder.id, action: :recording_stopped)
      assert_enqueued(worker: AssembleRecording, args: %{recording_id: id})

      assert %Recording{status: :processing, tracks: [%Track{user_id: ^owner_id, kind: :audio}]} =
               Recording.get(id: id)
    end
  end

  describe "list_recordings/2" do
    test "fails for someone outside the community", %{room: room, community: community} do
      stranger = TestUtils.register_random_user!()

      assert {:error, :forbidden} =
               Voice.list_recordings(stranger, {:room_id, room.id, community.id})
    end

    test "lists failed to recorders only", %{
      owner: owner,
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)
      scope = {:room_id, session.room_id, community.id}
      :ok = Voice.start_recording(owner, session)
      :ok = Voice.stop_recording(owner, session)
      :ok = TestUtils.await_recording_uploads!()

      assert {:ok, []} = Voice.list_recordings(member, scope)
      assert {:ok, [%Recording{status: :failed}]} = Voice.list_recordings(owner, scope)
    end
  end

  describe "rename_recording/3" do
    test "fails for someone who did not record it", %{
      owner: owner,
      moderator: moderator,
      community: community
    } do
      session = TestUtils.insert_random_voice_session!(community)
      recording = TestUtils.insert_random_ready_recording!(session, [{owner.id, "hello"}])

      assert {:error, :forbidden} = Voice.rename_recording(moderator, recording.id, "Notes")
    end

    test "fails with a blank title", %{owner: owner, community: community} do
      session = TestUtils.insert_random_voice_session!(community)
      recording = TestUtils.insert_random_ready_recording!(session, [{owner.id, "hello"}])

      assert {:error, %Ecto.Changeset{}} = Voice.rename_recording(owner, recording.id, "  ")
    end

    test "rename recording", %{owner: owner, community: community} do
      session = TestUtils.insert_random_voice_session!(community)
      recording = TestUtils.insert_random_ready_recording!(session, [{owner.id, "hello"}])
      %{id: recording_id} = recording

      assert {:ok, %Recording{title: "Notes"}} =
               Voice.rename_recording(owner, recording_id, " Notes ")

      assert_receive %VoiceRecordingRenamed{recording_id: ^recording_id, title: "Notes"}
    end
  end

  describe "delete_recording/2" do
    test "fails for someone who did not record it", %{
      owner: owner,
      moderator: moderator,
      community: community
    } do
      session = TestUtils.insert_random_voice_session!(community)
      recording = TestUtils.insert_random_ready_recording!(session, [{owner.id, "hello"}])

      assert {:error, :forbidden} = Voice.delete_recording(moderator, recording.id)
    end

    test "fails while it is still recording", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.start_recording(owner, session)
      recording = Recording.running(session.id)

      assert {:error, :still_recording} = Voice.delete_recording(owner, recording.id)
    end

    test "fails for a missing recording", %{owner: owner} do
      assert {:error, :not_found} = Voice.delete_recording(owner, Common.new_id())
    end

    test "delete recording", %{owner: owner, community: community} do
      session = TestUtils.insert_random_voice_session!(community)
      recording = TestUtils.insert_random_ready_recording!(session, [{owner.id, "hello"}])
      [%{key: key}] = recording.speakers
      %{id: recording_id} = recording

      assert {:ok, %Recording{}} = Voice.delete_recording(owner, recording_id)
      assert_receive %VoiceRecordingDeleted{recording_id: ^recording_id}
      assert {:error, :not_found} = Voice.get_recording(owner, recording.id)
      assert {:error, :not_found} = Storage.head(key)
    end
  end

  describe "end_session/2" do
    test "fails without host tools", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert {:error, :forbidden} = Voice.end_session(member, session)
    end

    test "end session", %{owner: owner, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: id} = session
      channel = TestUtils.start_fake_channel!()
      {:ok, _joined} = Voice.join(member, session, channel)

      assert :ok = Voice.end_session(owner, session)
      assert_receive %VoiceSessionEnded{session_id: ^id, reason: :ended}
      assert_receive {:voice_channel, ^channel, {:hearth_rtc, :closed, :ended}}, 1_000
      assert {:ok, %Session{ended_at: %DateTime{}}} = Voice.get_session(id: id)
      assert nil == Live.whereis(id)
    end

    test "stops the recording", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.start_recording(owner, session)

      assert :ok = Voice.end_session(owner, session)
      :ok = TestUtils.await_recording_uploads!()
      assert_receive %VoiceRecordingChanged{status: :processing}
      assert Action.exists?(actor_id: owner.id, action: :recording_stopped)
    end
  end

  describe "end_orphans/0" do
    test "ends sessions whose process is gone", %{community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: id} = session
      live = TestUtils.live_of!(session)
      :ok = DynamicSupervisor.terminate_child(Hearth.Voice.LiveSupervisor, live)

      assert 1 = Voice.end_orphans()
      assert_receive %VoiceSessionEnded{session_id: ^id, reason: :lost}
      assert {:ok, %Session{ended_at: %DateTime{}}} = Voice.get_session(id: id)
    end

    test "fails the recording of a lost session", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.start_recording(owner, session)
      live = TestUtils.live_of!(session)
      :ok = DynamicSupervisor.terminate_child(Hearth.Voice.LiveSupervisor, live)

      assert 1 = Voice.end_orphans()
      assert_receive %VoiceRecordingChanged{status: :failed}

      assert [%Recording{failure: "The recording was lost" <> _rest}] =
               Recording.all(session_id: session.id)
    end
  end

  describe "Live" do
    test "comes back once after a crash", %{member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: id} = session
      %{id: member_id} = member
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())
      live = TestUtils.live_of!(session)
      ref = Process.monitor(live)

      Process.exit(live, :kill)
      assert_receive {:DOWN, ^ref, :process, ^live, :killed}

      again = TestUtils.live_of!(session)
      assert %{participants: [%{user_id: ^member_id}]} = Live.snapshot(again)

      Process.exit(again, :kill)
      assert_receive %VoiceSessionEnded{session_id: ^id, reason: :lost}
    end

    test "broadcasts who is speaking", %{owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      %{id: owner_id} = owner
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())

      send(TestUtils.live_of!(session), {:hearth_rtc_peer, owner_id, {:speaking, true}})

      assert_receive %VoiceSpeakingChanged{user_ids: [^owner_id]}, 1_000
    end

    test "never shows the server muted speaking", %{
      owner: owner,
      speaker: speaker,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)
      %{id: owner_id} = owner
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())
      {:ok, _joined} = Voice.join(speaker, session, TestUtils.start_fake_channel!())
      :ok = Voice.server_mute(owner, session, speaker.id, true)
      live = TestUtils.live_of!(session)

      send(live, {:hearth_rtc_peer, speaker.id, {:speaking, true}})
      send(live, {:hearth_rtc_peer, owner_id, {:speaking, true}})

      assert_receive %VoiceSpeakingChanged{user_ids: [^owner_id]}, 1_000
    end
  end
end
