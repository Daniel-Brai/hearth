defmodule HearthWeb.Access.VisibilityTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.ChannelTest
  import HearthWeb.ChannelCase, only: [connected_socket: 1]

  alias Hearth.Communities
  alias Hearth.TestUtils

  @endpoint HearthWeb.Endpoint

  setup do
    owner = TestUtils.register_random_user!()
    stranger = TestUtils.register_random_user!()

    private = TestUtils.create_random_forum!(owner, visibility: :private)
    post = TestUtils.create_random_post!(owner, private)
    event = TestUtils.create_random_community_event!(owner, private)
    room = TestUtils.get_room!(private, type: :text)

    invite_only = TestUtils.create_random_forum!(owner, visibility: :invite_only)
    hidden_post = TestUtils.create_random_post!(owner, invite_only)

    {:ok, binding()}
  end

  describe "private community signed out" do
    test "hides the community", %{conn: conn, private: private} do
      assert conn |> get(~p"/api/communities/#{private.id}") |> response(404)
      assert conn |> get(~p"/api/communities/#{private.slug}") |> response(404)
      assert conn |> get(~p"/api/communities/#{private.id}/posts") |> response(404)
      assert conn |> get(~p"/api/communities/#{private.id}/members") |> response(404)
    end

    test "hides its post and event", %{conn: conn, post: post, event: event} do
      assert conn |> get(~p"/api/posts/#{post.id}") |> response(404)
      assert conn |> get(~p"/api/posts/#{post.id}/replies") |> response(404)
      assert conn |> get(~p"/og/posts/#{post.id}") |> response(404)
      assert conn |> get(~p"/og/events/#{event.id}") |> response(404)
    end

    test "leaves it out of public lists", %{conn: conn, private: private} do
      public = conn |> get(~p"/api/public/communities") |> json_response(200)

      refute private.id in TestUtils.pluck(public, "id")
      assert conn |> get(~p"/og/communities/#{private.slug}") |> response(404)
      assert conn |> get("/sitemaps/#{private.slug}.xml") |> response(404)
      refute conn |> get(~p"/sitemap.xml") |> response(200) =~ private.slug
    end

    test "leaves its posts off the author's profile", %{conn: conn, owner: owner, post: post} do
      %{"data" => posts} =
        conn |> get(~p"/api/users/#{owner.username}/posts") |> json_response(200)

      refute post.id in TestUtils.pluck(posts, "id")
    end
  end

  describe "private community to someone signed in outside it" do
    test "hides the community", %{conn: conn, stranger: stranger, private: private} do
      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/communities/#{private.id}")
             |> response(404)

      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/communities/#{private.id}/roles")
             |> response(404)

      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/events?community_id=#{private.id}")
             |> response(404)
    end

    test "hides its post", %{conn: conn, stranger: stranger, post: post} do
      assert conn |> auth_conn(stranger) |> get(~p"/api/posts/#{post.id}") |> response(404)

      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/posts/#{post.id}/recordings")
             |> response(404)
    end

    test "hides its room", %{conn: conn, stranger: stranger, room: room} do
      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/rooms/#{room.id}/messages")
             |> response(404)

      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/rooms/#{room.id}/recordings")
             |> response(404)

      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/rooms/#{room.id}/voice-session")
             |> response(404)
    end

    test "can't join it without an invite", %{conn: conn, stranger: stranger, private: private} do
      assert conn
             |> auth_conn(stranger)
             |> post(~p"/api/communities/#{private.id}/membership")
             |> response(404)
    end

    test "can't listen in on it", %{stranger: stranger, private: private, post: post, room: room} do
      socket = connected_socket(stranger)

      assert {:error, _reason} = subscribe_and_join(socket, "community:#{private.id}")
      assert {:error, _reason} = subscribe_and_join(socket, "post:#{post.id}")
      assert {:error, _reason} = subscribe_and_join(socket, "room:#{room.id}")
    end
  end

  describe "invite only community to someone signed in outside it" do
    test "shows only its outline", %{conn: conn, stranger: stranger, invite_only: invite_only} do
      assert %{"community" => community, "kinds" => [], "membership" => nil} =
               conn
               |> auth_conn(stranger)
               |> get(~p"/api/communities/#{invite_only.id}")
               |> json_response(200)

      assert %{"description" => nil, "rooms" => []} = community
    end

    test "hides what is inside", %{
      conn: conn,
      stranger: stranger,
      invite_only: invite_only,
      hidden_post: hidden_post
    } do
      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/communities/#{invite_only.id}/posts")
             |> response(404)

      assert conn |> auth_conn(stranger) |> get(~p"/api/posts/#{hidden_post.id}") |> response(404)

      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/communities/#{invite_only.id}/members")
             |> response(404)
    end

    test "can't join it without an invite", %{
      conn: conn,
      stranger: stranger,
      invite_only: invite_only
    } do
      assert %{"code" => "invite_required"} =
               conn
               |> auth_conn(stranger)
               |> post(~p"/api/communities/#{invite_only.id}/membership")
               |> json_response(400)
    end
  end

  describe "public community kept out of search" do
    setup %{owner: owner} do
      {:ok, unlisted: TestUtils.create_random_forum!(owner, visibility: :public)}
    end

    test "opens to anyone signed out", %{conn: conn, unlisted: unlisted} do
      assert conn |> get(~p"/api/communities/#{unlisted.id}") |> json_response(200)
      assert conn |> get(~p"/api/communities/#{unlisted.id}/posts") |> json_response(200)

      public = conn |> get(~p"/api/public/communities") |> json_response(200)
      assert unlisted.id in TestUtils.pluck(public, "id")
    end

    test "stays out of the sitemap", %{conn: conn, unlisted: unlisted} do
      assert conn |> get("/sitemaps/#{unlisted.slug}.xml") |> response(404)
      refute conn |> get(~p"/sitemap.xml") |> response(200) =~ unlisted.slug
    end

    test "keeps its chat for members", %{conn: conn, stranger: stranger, unlisted: unlisted} do
      room = TestUtils.get_room!(unlisted, type: :text)

      assert conn
             |> auth_conn(stranger)
             |> get(~p"/api/rooms/#{room.id}/messages")
             |> response(403)
    end
  end

  describe "private room to a member without its roles" do
    setup %{owner: owner} do
      open = TestUtils.create_random_forum!(owner, visibility: :public)
      member = TestUtils.join_random_member!(open)
      hidden = TestUtils.create_random_private_room!(open, ["moderator"])
      session = TestUtils.insert_random_voice_session!(open)
      {:ok, lounge} = Communities.get_room(id: session.room_id)
      {:ok, voice} = Communities.update_room(owner, lounge, %{access: :roles, role_ids: []})
      transcript = TestUtils.transcribe_random_recording!(session, [{owner.id, "0 1000 Hi"}])

      {:ok, binding()}
    end

    test "leaves it out of the community", %{
      conn: conn,
      member: member,
      open: open,
      hidden: hidden,
      voice: voice
    } do
      response =
        conn |> auth_conn(member) |> get(~p"/api/communities/#{open.id}") |> valid_response(200)

      room_ids = TestUtils.pluck(response["community"]["rooms"], "id")

      refute hidden.id in room_ids
      refute voice.id in room_ids
    end

    test "hides its chat", %{conn: conn, member: member, hidden: hidden} do
      assert conn
             |> auth_conn(member)
             |> get(~p"/api/rooms/#{hidden.id}/messages")
             |> response(404)

      assert conn
             |> auth_conn(member)
             |> post(~p"/api/rooms/#{hidden.id}/messages", %{body: "Hi"})
             |> response(404)

      assert conn
             |> auth_conn(member)
             |> put(~p"/api/rooms/#{hidden.id}/moderation", %{level: "none"})
             |> response(404)
    end

    test "hides its voice", %{conn: conn, member: member, voice: voice, session: session} do
      assert conn
             |> auth_conn(member)
             |> get(~p"/api/rooms/#{voice.id}/voice-session")
             |> response(404)

      assert conn
             |> auth_conn(member)
             |> get(~p"/api/voice-sessions/#{session.id}")
             |> response(404)

      assert conn
             |> auth_conn(member)
             |> get(~p"/api/rooms/#{voice.id}/recordings")
             |> response(404)

      assert conn
             |> auth_conn(member)
             |> get(~p"/api/voice-sessions/#{session.id}/transcript")
             |> response(404)
    end

    test "hides its recording", %{conn: conn, member: member, transcript: transcript} do
      assert conn
             |> auth_conn(member)
             |> get(~p"/api/recordings/#{transcript.recording_id}")
             |> response(404)
    end

    test "can't listen in on it", %{member: member, hidden: hidden, session: session} do
      socket = connected_socket(member)

      assert {:error, _reason} = subscribe_and_join(socket, "room:#{hidden.id}")
      assert {:error, _reason} = subscribe_and_join(socket, "voice:#{session.id}")
    end

    test "keeps its changes from the community topic", %{
      owner: owner,
      member: member,
      open: open,
      hidden: hidden
    } do
      socket = connected_socket(member)
      {:ok, _reply, _socket} = subscribe_and_join(socket, "community:#{open.id}")
      {:ok, _room} = Communities.update_room(owner, hidden, %{topic: "Plans"})
      hidden_id = hidden.id

      refute_push "RoomChanged", %{room_id: ^hidden_id}, 300
    end

    test "keeps a new private room from the community topic", %{member: member, open: open} do
      socket = connected_socket(member)
      {:ok, _reply, _socket} = subscribe_and_join(socket, "community:#{open.id}")
      %{id: room_id} = TestUtils.create_random_private_room!(open, ["moderator"])

      refute_push "RoomChanged", %{room_id: ^room_id}, 300
    end

    test "opens it to the owner", %{conn: conn, owner: owner, open: open, hidden: hidden} do
      response =
        conn |> auth_conn(owner) |> get(~p"/api/communities/#{open.id}") |> valid_response(200)

      assert hidden.id in TestUtils.pluck(response["community"]["rooms"], "id")

      assert conn
             |> auth_conn(owner)
             |> get(~p"/api/rooms/#{hidden.id}/messages")
             |> json_response(200)
    end

    test "tells the owner it changed", %{owner: owner, open: open, hidden: hidden} do
      socket = connected_socket(owner)
      {:ok, _reply, _socket} = subscribe_and_join(socket, "community:#{open.id}")
      {:ok, _room} = Communities.update_room(owner, hidden, %{topic: "Plans"})
      hidden_id = hidden.id

      assert_push "RoomChanged", %{room_id: ^hidden_id}, 1_000
    end

    test "closes the room once its role is gone", %{owner: owner, open: open, hidden: hidden} do
      moderator = TestUtils.join_random_member!(open)
      {:ok, _membership} = Communities.set_member_roles(owner, open, moderator, ["moderator"])
      socket = connected_socket(moderator)
      {:ok, _reply, _socket} = subscribe_and_join(socket, "room:#{hidden.id}")
      {:ok, _membership} = Communities.set_member_roles(owner, open, moderator, ["member"])
      hidden_id = hidden.id

      assert_push "room_hidden", %{room_id: ^hidden_id}, 1_000
    end

    test "tells the community to refetch rooms", %{member: member, owner: owner, open: open} do
      socket = connected_socket(member)
      {:ok, _reply, _socket} = subscribe_and_join(socket, "community:#{open.id}")
      {:ok, _membership} = Communities.set_member_roles(owner, open, member, ["member"])
      open_id = open.id

      assert_push "room_access_changed", %{community_id: ^open_id}, 1_000
    end
  end
end
