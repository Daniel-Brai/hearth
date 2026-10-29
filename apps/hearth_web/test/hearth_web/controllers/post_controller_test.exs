defmodule HearthWeb.PostControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Moderation
  alias Hearth.TestUtils
  alias Hearth.Transcripts.Transcript

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    {:ok, [kind | _kinds]} = Forum.create_default_kinds(community.id, community.template)
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)
    post = TestUtils.create_random_post!(member, community, kind_id: kind.id)

    {:ok, binding()}
  end

  describe "index" do
    test "returns 404 if private", %{conn: conn, owner: owner} do
      private = TestUtils.create_random_community!(owner, visibility: :private)

      assert conn
             |> get(~p"/api/communities/#{private.id}/posts")
             |> valid_response(404)
    end

    test "returns 404 if invite only", %{
      conn: conn,
      owner: owner
    } do
      community = TestUtils.create_random_forum!(owner, visibility: :invite_only)

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> get(~p"/api/communities/#{community.id}/posts")
             |> valid_response(404)
    end

    test "fails for a cursor that can't be used", %{conn: conn, community: community} do
      assert %{"code" => "invalid_paging"} =
               conn
               |> get(~p"/api/communities/#{community.id}/posts?after=nope")
               |> valid_response(400)
    end

    test "lists posts with their authors", %{
      conn: conn,
      community: community,
      member: member,
      post: post
    } do
      assert %{"data" => [entry], "meta" => meta} =
               conn
               |> get(~p"/api/communities/#{community.id}/posts")
               |> valid_response(200)

      assert entry["id"] == post.id
      assert entry["author"]["username"] == member.username
      assert meta["has_next"] == false
    end
  end

  describe "pinned" do
    test "lists pinned posts", %{conn: conn, owner: owner, community: community, post: post} do
      {:ok, _post} = Forum.pin_post(owner, post, true)

      assert [%{"id" => id, "pinned" => true}] =
               conn
               |> get(~p"/api/communities/#{community.id}/posts/pinned")
               |> valid_response(200)

      assert id == post.id
    end
  end

  describe "create" do
    test "fails without signing in", %{conn: conn, community: community, kind: kind} do
      body = %{kind_id: kind.id, title: Lorem.sentence()}

      assert conn
             |> post(~p"/api/communities/#{community.id}/posts", body)
             |> valid_response(401)
    end

    test "fails for someone outside the community", %{
      conn: conn,
      community: community,
      kind: kind
    } do
      body = %{kind_id: kind.id, title: Lorem.sentence()}

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/communities/#{community.id}/posts", body)
               |> valid_response(403)
    end

    test "fails due to validation", %{conn: conn, member: member, community: community} do
      body = %{title: ""}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/communities/#{community.id}/posts", body)
               |> valid_response(422)

      assert ["The kind_id field is required."] = errors["kind_id"]
      assert ["The title field is required."] = errors["title"]
    end

    test "fails for a kind from another community", %{
      conn: conn,
      member: member,
      community: community
    } do
      body = %{kind_id: Common.new_id(), title: Lorem.sentence()}

      assert %{"code" => "unknown_kind"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/communities/#{community.id}/posts", body)
               |> valid_response(400)
    end

    test "attaches files in order", %{
      conn: conn,
      member: member,
      community: community,
      kind: kind
    } do
      [first, second] = TestUtils.upload_random_attachments!(member, 2)
      body = %{kind_id: kind.id, title: Lorem.sentence(), attachment_ids: [second.id, first.id]}

      assert %{"attachments" => attachments} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/communities/#{community.id}/posts", body)
               |> valid_response(201)

      assert TestUtils.pluck(attachments, "id") == [second.id, first.id]
    end

    test "writes a post", %{conn: conn, member: member, community: community, kind: kind} do
      body = %{kind_id: kind.id, title: Lorem.sentence(), body: Lorem.paragraph()}

      assert response =
               conn
               |> auth_conn(member)
               |> post(~p"/api/communities/#{community.id}/posts", body)
               |> valid_response(201)

      assert response["title"] == body.title
      assert response["author"]["id"] == member.id
    end
  end

  describe "show" do
    test "returns 404 if missing", %{conn: conn} do
      assert conn |> get(~p"/api/posts/#{Common.new_id()}") |> valid_response(404)
    end

    test "shows a post", %{conn: conn, post: post} do
      assert response = conn |> get(~p"/api/posts/#{post.id}") |> valid_response(200)

      assert response["id"] == post.id
    end

    test "tells only the person who reported it", %{conn: conn, owner: owner} do
      community = TestUtils.create_random_forum!(owner, moderation: :reports)
      author = TestUtils.join_random_member!(community)
      reporter = TestUtils.join_random_member!(community)
      post = TestUtils.create_random_post!(author, community)
      {:ok, _item} = Moderation.report(reporter, :post, post.id, %{reason: :spam})

      assert %{"reported" => true} =
               conn
               |> auth_conn(reporter)
               |> get(~p"/api/posts/#{post.id}")
               |> valid_response(200)

      assert %{"reported" => false, "in_review" => true} =
               conn |> auth_conn(author) |> get(~p"/api/posts/#{post.id}") |> valid_response(200)
    end

    test "links its transcript for members", %{
      conn: conn,
      community: community,
      member: member,
      post: post
    } do
      session = TestUtils.insert_random_voice_session!(community)
      transcript = TestUtils.transcribe_random_recording!(session, [{member.id, "0 1000 Hi"}])
      :ok = TestUtils.update_rows!(Transcript, [id: transcript.id], post_id: post.id)
      session_id = session.id

      assert %{"transcript" => %{"session_id" => ^session_id, "duration_ms" => 60_000}} =
               conn |> auth_conn(member) |> get(~p"/api/posts/#{post.id}") |> valid_response(200)

      assert %{"transcript" => nil} =
               conn |> get(~p"/api/posts/#{post.id}") |> valid_response(200)
    end
  end

  describe "update" do
    test "fails if not the author", %{conn: conn, owner: owner, post: post} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/posts/#{post.id}", %{title: Lorem.sentence()})
               |> valid_response(403)
    end

    test "edits a post", %{conn: conn, member: member, post: post} do
      body = %{title: Lorem.sentence()}

      assert response =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/posts/#{post.id}", body)
               |> valid_response(200)

      assert response["title"] == body.title
      assert response["edited_at"]
    end
  end

  describe "delete" do
    test "fails if not author or moderator", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      post = TestUtils.create_random_post!(owner, community)
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> delete(~p"/api/posts/#{post.id}")
               |> valid_response(403)
    end

    test "fails if user can moderate", %{
      conn: conn,
      owner: owner,
      post: post
    } do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(owner)
               |> delete(~p"/api/posts/#{post.id}")
               |> valid_response(403)
    end

    test "deletes the author's post", %{conn: conn, member: member, post: post} do
      assert conn |> auth_conn(member) |> delete(~p"/api/posts/#{post.id}") |> response(204)
      assert conn |> get(~p"/api/posts/#{post.id}") |> valid_response(404)
    end
  end

  describe "pin" do
    test "fails for a member without the permission", %{conn: conn, member: member, post: post} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/posts/#{post.id}/pin", %{pinned: true})
               |> valid_response(403)
    end

    test "pins a post", %{conn: conn, owner: owner, post: post} do
      assert %{"pinned" => true} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/posts/#{post.id}/pin", %{pinned: true})
               |> valid_response(200)
    end
  end

  describe "lock" do
    test "locks a post", %{conn: conn, owner: owner, post: post} do
      assert %{"locked" => true} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/posts/#{post.id}/lock", %{locked: true})
               |> valid_response(200)
    end
  end

  describe "helpful" do
    test "fails for the post's own author", %{conn: conn, member: member, post: post} do
      assert %{"code" => "own"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/posts/#{post.id}/helpful")
               |> valid_response(400)
    end

    test "marks and unmarks a post", %{conn: conn, owner: owner, post: post} do
      assert %{"on" => true} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/helpful")
               |> valid_response(200)

      assert %{"on" => false} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/helpful")
               |> valid_response(200)
    end
  end

  describe "react" do
    test "fails for something that isn't one emoji", %{conn: conn, owner: owner, post: post} do
      assert %{"code" => "invalid_emoji"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/reactions", %{emoji: String.duplicate("a", 20)})
               |> valid_response(400)
    end

    test "adds and takes back a reaction", %{conn: conn, owner: owner, post: post} do
      assert %{"on" => true} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/reactions", %{emoji: "🎉"})
               |> valid_response(200)

      assert %{"reactions" => [%{"emoji" => "🎉", "count" => 1, "mine" => true}]} =
               conn |> auth_conn(owner) |> get(~p"/api/posts/#{post.id}") |> valid_response(200)

      assert %{"reactions" => [%{"mine" => false}]} =
               conn |> get(~p"/api/posts/#{post.id}") |> valid_response(200)

      assert %{"on" => false} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/reactions", %{emoji: "🎉"})
               |> valid_response(200)
    end
  end

  describe "seen" do
    test "records that the post was read", %{conn: conn, owner: owner, post: post} do
      assert conn |> auth_conn(owner) |> post(~p"/api/posts/#{post.id}/seen") |> response(204)
    end
  end

  describe "all_seen" do
    test "fails signed out", %{conn: conn} do
      conn |> post(~p"/api/posts/seen") |> valid_response(401)
    end

    test "marks every joined community's posts read", %{conn: conn, owner: owner, post: post} do
      conn |> auth_conn(owner) |> post(~p"/api/posts/seen") |> response(204)

      assert %{"seen" => true} =
               conn |> auth_conn(owner) |> get(~p"/api/posts/#{post.id}") |> valid_response(200)
    end
  end

  describe "community_seen" do
    test "fails for a missing community", %{conn: conn, owner: owner} do
      conn
      |> auth_conn(owner)
      |> post(~p"/api/communities/#{Common.new_id()}/posts/seen")
      |> valid_response(404)
    end

    test "marks the community's posts read", %{
      conn: conn,
      owner: owner,
      community: community,
      post: post
    } do
      assert %{"seen" => false} =
               conn |> auth_conn(owner) |> get(~p"/api/posts/#{post.id}") |> valid_response(200)

      conn
      |> auth_conn(owner)
      |> post(~p"/api/communities/#{community.id}/posts/seen")
      |> response(204)

      assert %{"seen" => true} =
               conn |> auth_conn(owner) |> get(~p"/api/posts/#{post.id}") |> valid_response(200)
    end
  end

  describe "preview" do
    test "fails for someone who can't hide it", %{conn: conn, community: community, post: post} do
      stranger = TestUtils.join_random_member!(community)

      conn
      |> auth_conn(stranger)
      |> put(~p"/api/posts/#{post.id}/preview", %{hidden: true})
      |> valid_response(403)
    end

    test "takes the link card off", %{conn: conn, member: member, post: post} do
      conn
      |> auth_conn(member)
      |> put(~p"/api/posts/#{post.id}/preview", %{hidden: true})
      |> response(204)

      assert %{"preview_hidden" => true} =
               conn |> get(~p"/api/posts/#{post.id}") |> valid_response(200)
    end
  end

  describe "watch" do
    test "fails signed out", %{conn: conn, post: post} do
      assert conn
             |> put(~p"/api/posts/#{post.id}/watch", %{watching: true})
             |> valid_response(401)
    end

    test "returns 404 for a post that doesn't exist", %{conn: conn, owner: owner} do
      assert conn
             |> auth_conn(owner)
             |> put(~p"/api/posts/#{Common.new_id()}/watch", %{watching: true})
             |> valid_response(404)
    end

    test "watches a post and stops", %{conn: conn, owner: owner, post: post} do
      assert %{"on" => true} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/posts/#{post.id}/watch", %{watching: true})
               |> valid_response(200)

      assert %{"watching" => true} =
               conn |> auth_conn(owner) |> get(~p"/api/posts/#{post.id}") |> valid_response(200)

      assert %{"on" => false} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/posts/#{post.id}/watch", %{watching: false})
               |> valid_response(200)

      assert %{"watching" => false} =
               conn |> auth_conn(owner) |> get(~p"/api/posts/#{post.id}") |> valid_response(200)
    end
  end

  describe "promote" do
    setup %{community: community, member: member} do
      room = TestUtils.get_room!(community, type: :text)
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      {:ok, binding()}
    end

    test "fails without chat.promote", %{conn: conn, member: member, room: room} = context do
      body = %{
        message_ids: [context.message.id],
        kind_id: context.kind.id,
        title: Lorem.sentence()
      }

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/posts", body)
               |> valid_response(403)
    end

    test "fails without messages", %{conn: conn, owner: owner, room: room, kind: kind} do
      body = %{message_ids: [], kind_id: kind.id, title: Lorem.sentence()}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/rooms/#{room.id}/posts", body)
               |> valid_response(422)

      assert ["The message_ids field is required." | _rest] = errors["message_ids"]
    end

    test "fails for a message from another room", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community,
      room: room,
      kind: kind
    } do
      other = TestUtils.get_room!(community, slug: "help")
      {:ok, message} = Chat.send_message(member, other, %{body: Lorem.sentence()})
      body = %{message_ids: [message.id], kind_id: kind.id, title: Lorem.sentence()}

      assert %{"code" => "invalid_messages"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/rooms/#{room.id}/posts", body)
               |> valid_response(400)
    end

    test "turns messages into a post", %{
      conn: conn,
      owner: owner,
      member: member,
      room: room,
      message: message,
      kind: kind
    } do
      {:ok, reply} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      body = %{message_ids: [reply.id, message.id], kind_id: kind.id, title: Lorem.sentence()}

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/rooms/#{room.id}/posts", body)
               |> valid_response(201)

      assert response["author"]["id"] == member.id
      assert response["body"] == message.body
      assert response["reply_count"] == 1

      assert %{"room_id" => room_id, "message_count" => 2, "promoted_by" => promoted_by} =
               response["from_chat"]

      assert room_id == room.id
      assert promoted_by["id"] == owner.id
    end
  end
end
