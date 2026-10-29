defmodule HearthWeb.VoiceChannelTest do
  # Sessions and peers run in their own processes and write to the database.
  use HearthWeb.ChannelCase, async: false

  alias Hearth.TestUtils
  alias Hearth.Voice
  alias Hearth.Voice.VoiceParticipantChanged
  alias HearthWeb.FakeBrowser

  setup do
    :ok = TestUtils.start_voice!()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    outsider = TestUtils.register_random_user!()
    session = TestUtils.start_random_voice_session!(community)

    {:ok, binding()}
  end

  describe "voice:<id>" do
    test "fails for someone outside the community", %{outsider: outsider, session: session} do
      assert {:error, %{reason: "forbidden"}} =
               outsider |> connected_socket() |> subscribe_and_join("voice:#{session.id}")
    end

    test "fails for a topic that isn't an id", %{owner: owner} do
      assert {:error, %{reason: "not_found"}} =
               owner |> connected_socket() |> subscribe_and_join("voice:nope")
    end

    test "fails for a session that ended", %{owner: owner, session: session} do
      :ok = Voice.end_session(owner, session)

      assert {:error, %{reason: "not_live"}} =
               owner |> connected_socket() |> subscribe_and_join("voice:#{session.id}")
    end

    test "joins and gets the first offer", %{owner: owner, member: member, session: session} do
      {_owner, _reply} = owner |> connected_socket() |> FakeBrowser.start!(session.id, :host)

      assert {:ok, reply, _socket} =
               member |> connected_socket() |> subscribe_and_join("voice:#{session.id}")

      assert %{me: %{role: :listener}} = reply
      assert_push "offer", %{sdp: "v=0" <> _sdp, tracks: tracks}, 1_000
      assert [%{kind: :audio, direction: :receive} = track] = Map.values(tracks)
      assert track.user_id == owner.id
    end

    test "takes someone who leaves out at once", %{member: member, session: session} do
      %{id: member_id} = member
      :ok = Voice.subscribe_to_pubsub()

      topic = "voice:#{session.id}"
      {:ok, _reply, socket} = member |> connected_socket() |> subscribe_and_join(topic)

      Process.unlink(socket.channel_pid)
      leave(socket)

      assert_receive %VoiceParticipantChanged{user_id: ^member_id, left: true}
    end

    test "pushes Disconnected on host kick", %{
      owner: owner,
      member: member,
      session: session
    } do
      topic = "voice:#{session.id}"
      {:ok, _reply, _socket} = member |> connected_socket() |> subscribe_and_join(topic)

      :ok = Voice.disconnect(owner, session, member.id)

      assert_push "Disconnected", %{reason: :disconnected}, 1_000
    end
  end

  describe "captions" do
    test "fails where speech isn't turned into text", %{member: member, session: session} do
      TestUtils.put_transcription(:off)

      topic = "voice:#{session.id}"
      {:ok, _reply, socket} = member |> connected_socket() |> subscribe_and_join(topic)

      ref = push(socket, "captions", %{"on" => true})
      assert_reply ref, :error, %{reason: "transcription_off"}
    end

    test "turns captions on for the room", %{member: member, session: session} do
      topic = "voice:#{session.id}"
      {:ok, _reply, socket} = member |> connected_socket() |> subscribe_and_join(topic)

      ref = push(socket, "captions", %{"on" => true})
      assert_reply ref, :ok
    end
  end

  describe "react" do
    test "fails if not an emoji shortcode", %{member: member, session: session} do
      topic = "voice:#{session.id}"
      {:ok, _reply, socket} = member |> connected_socket() |> subscribe_and_join(topic)

      ref = push(socket, "react", %{"emoji" => "<b>hi</b>"})
      assert_reply ref, :error, %{reason: "invalid_emoji"}
    end

    test "closes once the person leaves", %{member: member, session: session} do
      topic = "voice:#{session.id}"
      {:ok, _reply, socket} = member |> connected_socket() |> subscribe_and_join(topic)

      ref = Process.monitor(socket.channel_pid)
      :ok = Voice.leave(member, session)

      assert_push "Disconnected", %{reason: :left}, 1_000
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}, 1_000
    end

    test "drops reactions past five a second", %{member: member, session: session} do
      topic = "voice:#{session.id}"
      {:ok, _reply, socket} = member |> connected_socket() |> subscribe_and_join(topic)

      :ok = push_times(socket, "react", %{"emoji" => ":tada:"}, 7)

      assert_broadcast "VoiceReaction", %{emoji: ":tada:"}, 1_000
      assert_broadcast "VoiceReaction", %{emoji: ":tada:"}, 1_000
      assert_broadcast "VoiceReaction", %{emoji: ":tada:"}, 1_000
      assert_broadcast "VoiceReaction", %{emoji: ":tada:"}, 1_000
      assert_broadcast "VoiceReaction", %{emoji: ":tada:"}, 1_000
      refute_broadcast "VoiceReaction", _payload, 200
    end

    test "floats a reaction to everyone in the session", %{member: member, session: session} do
      %{id: member_id} = member

      topic = "voice:#{session.id}"
      {:ok, _reply, socket} = member |> connected_socket() |> subscribe_and_join(topic)

      push(socket, "react", %{"emoji" => ":heart:"})

      assert_broadcast "VoiceReaction", %{user_id: ^member_id, emoji: ":heart:"}, 1_000
    end
  end

  describe "media" do
    test "carries a speaker's audio to a listener", %{
      owner: owner,
      member: member,
      session: session
    } do
      %{id: owner_id} = owner
      {host, _reply} = owner |> connected_socket() |> FakeBrowser.start!(session.id, :host)

      {_listener, _reply} =
        member |> connected_socket() |> FakeBrowser.start!(session.id, :listener)

      assert_receive {:browser, :host, :connected}, 5_000
      assert_receive {:browser, :listener, :connected}, 5_000

      FakeBrowser.stream(host, :audio, "hello", 100)

      assert_receive {:browser, :listener, {:rtp, ^owner_id, :audio, "hello"}}, 5_000
    end

    test "drops a server muted speaker's audio", %{
      owner: owner,
      member: member,
      session: session
    } do
      %{id: owner_id} = owner
      {host, _reply} = owner |> connected_socket() |> FakeBrowser.start!(session.id, :host)

      {_listener, _reply} =
        member |> connected_socket() |> FakeBrowser.start!(session.id, :listener)

      assert_receive {:browser, :host, :connected}, 5_000
      assert_receive {:browser, :listener, :connected}, 5_000
      FakeBrowser.stream(host, :audio, "before", 100)
      assert_receive {:browser, :listener, {:rtp, ^owner_id, :audio, "before"}}, 5_000

      :ok = Voice.server_mute(owner, session, owner_id, true)
      FakeBrowser.stream(host, :audio, "muted", 25)

      refute_receive {:browser, :listener, {:rtp, ^owner_id, :audio, "muted"}}, 1_000
    end

    test "asks sharer for keyframe", %{
      owner: owner,
      member: member,
      session: session
    } do
      %{id: owner_id} = owner
      {host, _reply} = owner |> connected_socket() |> FakeBrowser.start!(session.id, :host)
      assert_receive {:browser, :host, :connected}, 5_000
      :ok = Voice.start_share(owner, session)
      assert_receive {:browser, :host, {:push, "VoiceShareChanged", _payload}}, 5_000
      FakeBrowser.stream(host, :video, "frame", 250)

      {_watcher, _reply} =
        member |> connected_socket() |> FakeBrowser.start!(session.id, :watcher)

      assert_receive {:browser, :watcher, :connected}, 5_000
      assert_receive {:browser, :host, :pli}, 5_000
      assert_receive {:browser, :watcher, {:rtp, ^owner_id, :video, "frame"}}, 5_000
    end
  end
end
