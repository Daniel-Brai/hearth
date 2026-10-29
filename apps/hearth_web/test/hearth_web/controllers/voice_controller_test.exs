defmodule HearthWeb.VoiceControllerTest do
  # Sessions run in their own processes and write to the database.
  use HearthWeb.ConnCase, async: false

  alias Hearth.TestUtils
  alias Hearth.Voice

  setup do
    :ok = TestUtils.start_voice!()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    room = TestUtils.create_random_voice_room!(community)
    outsider = TestUtils.register_random_user!()

    {:ok, binding()}
  end

  describe "live" do
    test "fails for a room that isn't live", %{conn: conn, member: member, room: room} do
      assert %{"code" => "not_found"} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/rooms/#{room.id}/voice-session")
               |> valid_response(404)
    end

    test "fails for someone outside the community", %{
      conn: conn,
      outsider: outsider,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "not_found"} =
               conn
               |> auth_conn(outsider)
               |> get(~p"/api/rooms/#{session.room_id}/voice-session")
               |> valid_response(404)
    end

    test "gets the live session", %{conn: conn, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"ended_at" => nil} =
               response =
               conn
               |> auth_conn(member)
               |> get(~p"/api/rooms/#{session.room_id}/voice-session")
               |> valid_response(200)

      assert response["id"] == session.id
    end
  end

  describe "live_index" do
    test "leaves out communities one isn't in", %{
      conn: conn,
      outsider: outsider,
      community: community
    } do
      _session = TestUtils.start_random_voice_session!(community)

      assert [] =
               conn
               |> auth_conn(outsider)
               |> get(~p"/api/voice-sessions/live")
               |> valid_response(200)
    end

    test "lists my communities' live sessions", %{
      conn: conn,
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)

      assert [%{"ended_at" => nil, "recording" => false, "people" => 0} = live] =
               conn
               |> auth_conn(member)
               |> get(~p"/api/voice-sessions/live")
               |> valid_response(200)

      assert live["id"] == session.id
    end
  end

  describe "discuss" do
    setup %{owner: owner} do
      forum = TestUtils.create_random_forum!(owner, template: "blank")
      forum_room = TestUtils.create_random_voice_room!(forum)
      post = TestUtils.create_random_post!(owner, forum)

      {:ok, binding()}
    end

    test "fails for someone who didn't write the post", %{conn: conn, forum: forum, post: post} do
      moderator = TestUtils.join_with_permissions!(forum, ["voice-session.create"])

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(moderator)
               |> post(~p"/api/posts/#{post.id}/live")
               |> valid_response(403)
    end

    test "fails when every voice room is live", %{
      conn: conn,
      owner: owner,
      forum_room: forum_room,
      post: post
    } do
      {:ok, _session} = Voice.start_session(owner, forum_room, %{})

      assert %{"code" => "rooms_busy"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/live")
               |> valid_response(400)
    end

    test "starts a discussion of the post", %{
      conn: conn,
      owner: owner,
      forum_room: forum_room,
      post: post
    } do
      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/live")
               |> valid_response(201)

      assert response["post_id"] == post.id
      assert response["room_id"] == forum_room.id
      assert response["topic"] == post.title
    end

    test "gives the discussion while it is live", %{conn: conn, owner: owner, post: post} do
      {:ok, session} = Voice.discuss_live(owner, post)

      assert %{"id" => id} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/live")
               |> valid_response(200)

      assert id == session.id
    end

    test "shows on the post while it is live", %{conn: conn, owner: owner, post: post} do
      assert %{"live" => nil} = conn |> get(~p"/api/posts/#{post.id}") |> valid_response(200)
      {:ok, session} = Voice.discuss_live(owner, post)

      assert %{"live" => %{"session_id" => id}} =
               conn |> get(~p"/api/posts/#{post.id}") |> valid_response(200)

      assert id == session.id
    end
  end

  describe "create" do
    test "fails if not allowed", %{conn: conn, member: member, room: room} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/voice-sessions", %{})
               |> valid_response(403)
    end

    test "fails without an rtc node", %{conn: conn, owner: owner, room: room} do
      :ok = TestUtils.stop_rtc!()

      assert %{"code" => "unavailable"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/rooms/#{room.id}/voice-sessions", %{})
               |> valid_response(400)
    end

    test "starts a session", %{conn: conn, owner: owner, room: room} do
      body = %{mode: "open", topic: "Planning"}

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/rooms/#{room.id}/voice-sessions", body)
               |> valid_response(201)

      assert response["host_id"] == owner.id
      assert response["mode"] == body.mode
      assert response["topic"] == body.topic
    end

    test "gives the live one", %{conn: conn, owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/rooms/#{session.room_id}/voice-sessions", %{})
               |> valid_response(200)

      assert response["id"] == session.id
    end
  end

  describe "show" do
    test "fails for someone outside the community", %{
      conn: conn,
      outsider: outsider,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(outsider)
               |> get(~p"/api/voice-sessions/#{session.id}")
               |> valid_response(403)
    end

    test "shows the session", %{conn: conn, owner: owner, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert %{"host_tools" => false, "share" => nil} =
               response =
               conn
               |> auth_conn(member)
               |> get(~p"/api/voice-sessions/#{session.id}")
               |> valid_response(200)

      assert [%{"role" => "listener"} = participant] = response["participants"]
      assert participant["user_id"] == member.id

      assert %{"host_tools" => true} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/voice-sessions/#{session.id}")
               |> valid_response(200)
    end
  end

  describe "end_session" do
    test "fails without host tools", %{conn: conn, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/voice-sessions/#{session.id}/end")
               |> valid_response(403)
    end

    test "ends the session", %{conn: conn, owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/voice-sessions/#{session.id}/end")
             |> response(204)
    end
  end

  describe "hand" do
    test "fails for someone not in the session", %{
      conn: conn,
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "not_here"} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/voice-sessions/#{session.id}/hand", %{raised: true})
               |> valid_response(400)
    end

    test "raises a hand", %{conn: conn, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert conn
             |> auth_conn(member)
             |> put(~p"/api/voice-sessions/#{session.id}/hand", %{raised: true})
             |> response(204)
    end
  end

  describe "mute" do
    test "shows a self mute", %{conn: conn, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert conn
             |> auth_conn(member)
             |> put(~p"/api/voice-sessions/#{session.id}/mute", %{muted: false})
             |> response(204)
    end
  end

  describe "invite" do
    test "fails without host tools", %{conn: conn, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/voice-sessions/#{session.id}/participants/#{member.id}/invite")
               |> valid_response(403)
    end

    test "invites a listener", %{conn: conn, owner: owner, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/voice-sessions/#{session.id}/participants/#{member.id}/invite")
             |> response(204)
    end
  end

  describe "demote" do
    test "fails for a listener", %{conn: conn, owner: owner, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert %{"code" => "invalid_transition"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/voice-sessions/#{session.id}/participants/#{member.id}/demote")
               |> valid_response(400)
    end

    test "moves a speaker to listeners", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())
      :ok = Voice.invite(owner, session, member.id)

      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/voice-sessions/#{session.id}/participants/#{member.id}/demote")
             |> response(204)
    end
  end

  describe "server_mute" do
    test "fails without host tools", %{conn: conn, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> put(
                 ~p"/api/voice-sessions/#{session.id}/participants/#{member.id}/server-mute",
                 %{muted: true}
               )
               |> valid_response(403)
    end

    test "server mutes someone", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert conn
             |> auth_conn(owner)
             |> put(
               ~p"/api/voice-sessions/#{session.id}/participants/#{member.id}/server-mute",
               %{muted: true}
             )
             |> response(204)
    end
  end

  describe "disconnect" do
    test "fails without host tools", %{conn: conn, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> delete(~p"/api/voice-sessions/#{session.id}/participants/#{member.id}")
               |> valid_response(403)
    end

    test "disconnects someone", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert conn
             |> auth_conn(owner)
             |> delete(~p"/api/voice-sessions/#{session.id}/participants/#{member.id}")
             |> response(204)
    end
  end

  describe "start_share" do
    test "fails off stage", %{conn: conn, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(member, session, TestUtils.start_fake_channel!())

      assert %{"code" => "not_on_stage"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/voice-sessions/#{session.id}/share")
               |> valid_response(400)
    end

    test "takes the share", %{conn: conn, owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())

      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/voice-sessions/#{session.id}/share")
             |> response(204)
    end
  end

  describe "stop_share" do
    test "fails when nobody shares", %{conn: conn, owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "not_sharing"} =
               conn
               |> auth_conn(owner)
               |> delete(~p"/api/voice-sessions/#{session.id}/share")
               |> valid_response(400)
    end

    test "stops the share", %{conn: conn, owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      {:ok, _joined} = Voice.join(owner, session, TestUtils.start_fake_channel!())
      :ok = Voice.start_share(owner, session)

      assert conn
             |> auth_conn(owner)
             |> delete(~p"/api/voice-sessions/#{session.id}/share")
             |> response(204)
    end
  end

  describe "start_recording" do
    test "fails without voice-recording.create", %{
      conn: conn,
      member: member,
      community: community
    } do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/voice-sessions/#{session.id}/recording")
               |> valid_response(403)
    end

    test "fails while one runs", %{conn: conn, owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.start_recording(owner, session)

      assert %{"code" => "already_recording"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/voice-sessions/#{session.id}/recording")
               |> valid_response(400)
    end

    test "starts recording", %{conn: conn, owner: owner, member: member, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/voice-sessions/#{session.id}/recording")
             |> response(204)

      assert response =
               conn
               |> auth_conn(member)
               |> get(~p"/api/voice-sessions/#{session.id}")
               |> valid_response(200)

      assert response["recording"]["started_by_id"] == owner.id
    end
  end

  describe "stop_recording" do
    test "fails when nothing records", %{conn: conn, owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert %{"code" => "not_recording"} =
               conn
               |> auth_conn(owner)
               |> delete(~p"/api/voice-sessions/#{session.id}/recording")
               |> valid_response(400)
    end

    test "stops recording", %{conn: conn, owner: owner, community: community} do
      session = TestUtils.start_random_voice_session!(community)
      :ok = Voice.start_recording(owner, session)

      assert conn
             |> auth_conn(owner)
             |> delete(~p"/api/voice-sessions/#{session.id}/recording")
             |> response(204)

      :ok = TestUtils.await_recording_uploads!()
    end
  end
end
