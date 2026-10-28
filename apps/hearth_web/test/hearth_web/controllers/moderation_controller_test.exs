defmodule HearthWeb.ModerationControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Forum
  alias Hearth.Moderation
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner, moderation: :reports)
    author = TestUtils.join_random_member!(community)
    reporter = TestUtils.join_random_member!(community)
    post = TestUtils.create_random_post!(author, community)
    {:ok, item} = Moderation.report(reporter, :post, post.id, %{reason: :spam})

    {:ok, binding()}
  end

  describe "queue" do
    test "fails without content.remove", %{conn: conn, reporter: reporter, community: community} do
      assert conn
             |> auth_conn(reporter)
             |> get(~p"/api/communities/#{community.id}/moderation/queue")
             |> valid_response(403)
    end

    test "lists waiting items", %{
      conn: conn,
      community: community,
      item: item,
      post: post
    } do
      helper = TestUtils.join_with_permissions!(community, ["content.remove"])

      assert %{"data" => [response]} =
               conn
               |> auth_conn(helper)
               |> get(~p"/api/communities/#{community.id}/moderation/queue")
               |> valid_response(200)

      assert response["id"] == item.id
      assert response["subject"]["title"] == post.title
      assert [%{"reason" => "spam"}] = response["reports"]
    end
  end

  describe "counts" do
    test "counts what waits in each queue", %{conn: conn, owner: owner, community: community} do
      community_id = community.id

      assert %{"counts" => %{^community_id => 1}} =
               conn |> auth_conn(owner) |> get(~p"/api/moderation/counts") |> valid_response(200)
    end
  end

  describe "instance_queue" do
    test "fails for someone who isn't an instance admin", %{conn: conn, reporter: reporter} do
      assert conn |> auth_conn(reporter) |> get(~p"/api/instance/reports") |> valid_response(403)
    end

    test "lists reported direct messages", %{conn: conn, author: author, reporter: reporter} do
      admin = TestUtils.register_random_user!(admin: true)
      {:ok, conversation} = Chat.start_direct(author, reporter)
      {:ok, message} = Chat.send_message(author, conversation, %{body: Lorem.sentence()})
      {:ok, _item} = Moderation.report(reporter, :message, message.id, %{reason: :harassment})

      assert %{"data" => [%{"source" => "instance", "community_id" => nil}]} =
               conn |> auth_conn(admin) |> get(~p"/api/instance/reports") |> valid_response(200)
    end
  end

  describe "screening_summary" do
    test "fails for someone who isn't an instance admin", %{conn: conn, reporter: reporter} do
      assert conn
             |> auth_conn(reporter)
             |> get(~p"/api/instance/screening")
             |> valid_response(403)
    end

    test "shows holds per day", %{conn: conn, owner: owner} do
      admin = TestUtils.register_random_user!(admin: true)
      community = TestUtils.create_random_forum!(owner, moderation: :full)
      post = TestUtils.create_random_post!(owner, community, body: "[unsafe]")
      {:ok, _item} = Moderation.screen(:post, post.id)

      assert %{"threshold" => 0.5, "days" => [%{"screened" => 1, "held" => 1, "kept" => 0}]} =
               conn
               |> auth_conn(admin)
               |> get(~p"/api/instance/screening?days=7")
               |> valid_response(200)
    end
  end

  describe "keep" do
    test "fails without content.remove", %{conn: conn, reporter: reporter, item: item} do
      assert conn
             |> auth_conn(reporter)
             |> post(~p"/api/moderation/items/#{item.id}/keep", %{})
             |> valid_response(403)
    end

    test "keeps the content up", %{conn: conn, owner: owner, item: item} do
      assert %{"status" => "kept"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/items/#{item.id}/keep", %{})
               |> valid_response(200)
    end
  end

  describe "remove" do
    test "fails without a reason", %{conn: conn, owner: owner, item: item} do
      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/moderation/items/#{item.id}/remove", %{})
             |> valid_response(422)
    end

    test "removes the content", %{conn: conn, owner: owner, item: item, post: post} do
      assert %{"status" => "removed", "subject" => %{"status" => "removed"}} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/items/#{item.id}/remove", %{reason: Lorem.sentence()})
               |> valid_response(200)

      assert {:ok, %{status: :removed}} = Forum.get_post(id: post.id)
    end
  end

  describe "undo" do
    test "fails for an item still waiting", %{conn: conn, owner: owner, item: item} do
      assert %{"code" => "invalid_transition"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/items/#{item.id}/undo")
               |> valid_response(400)
    end

    test "puts removed content back", %{conn: conn, owner: owner, item: item} do
      {:ok, removed} = Moderation.remove(owner, item, Lorem.sentence())

      assert %{"status" => "pending", "subject" => %{"status" => "published"}} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/items/#{removed.id}/undo")
               |> valid_response(200)
    end
  end

  describe "ban_author" do
    test "fails without member.ban", %{conn: conn, community: community, item: item} do
      helper = TestUtils.join_with_permissions!(community, ["content.remove"])

      assert conn
             |> auth_conn(helper)
             |> post(~p"/api/moderation/items/#{item.id}/ban", %{reason: Lorem.sentence()})
             |> valid_response(403)
    end

    test "bans the author", %{conn: conn, owner: owner, author: author, item: item} do
      assert %{"user" => %{"id" => user_id}} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/items/#{item.id}/ban", %{reason: Lorem.sentence()})
               |> valid_response(201)

      assert user_id == author.id
    end
  end

  describe "remove_content" do
    test "fails without content.remove", %{conn: conn, reporter: reporter, post: post} do
      body = %{subject_type: "post", subject_id: post.id, reason: Lorem.sentence()}

      assert conn
             |> auth_conn(reporter)
             |> post(~p"/api/moderation/remove", body)
             |> valid_response(403)
    end

    test "fails without a reason", %{conn: conn, owner: owner, post: post} do
      body = %{subject_type: "post", subject_id: post.id}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/remove", body)
               |> valid_response(422)

      assert ["The reason field is required."] = errors["reason"]
    end

    test "removes a reply from its menu", %{conn: conn, owner: owner, author: author, post: post} do
      {:ok, reply} = Forum.reply(author, post, %{body: Lorem.sentence()})
      body = %{subject_type: "reply", subject_id: reply.id, reason: Lorem.sentence()}

      assert %{"status" => "removed"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/remove", body)
               |> valid_response(200)

      assert %{"data" => [%{"body" => nil, "author" => nil, "status" => "removed"}]} =
               conn |> get(~p"/api/posts/#{post.id}/replies") |> valid_response(200)
    end
  end

  describe "restore_content" do
    test "fails for content that wasn't removed", %{conn: conn, owner: owner, post: post} do
      body = %{subject_type: "post", subject_id: post.id}

      assert %{"code" => "not_removed"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/restore", body)
               |> valid_response(400)
    end

    test "puts it back", %{conn: conn, owner: owner, post: post} do
      {:ok, _subject} = Moderation.remove_content(owner, :post, post.id, Lorem.sentence())
      body = %{subject_type: "post", subject_id: post.id}

      assert %{"status" => "published"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/moderation/restore", body)
               |> valid_response(200)
    end
  end

  describe "community_level" do
    test "fails unless the Owner", %{conn: conn, reporter: reporter, community: community} do
      assert conn
             |> auth_conn(reporter)
             |> put(~p"/api/communities/#{community.id}/moderation", %{level: "full"})
             |> valid_response(403)
    end

    test "fails for null", %{conn: conn, owner: owner, community: community} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/moderation", %{level: nil})
               |> valid_response(422)

      assert ["The level field is required."] = errors["level"]
    end

    test "sets the level", %{conn: conn, owner: owner, community: community} do
      assert %{"level" => "full", "effective" => "full"} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/moderation", %{level: "full"})
               |> valid_response(200)
    end
  end

  describe "room_level" do
    test "fails above the community", %{conn: conn, owner: owner, community: community} do
      room = TestUtils.get_room!(community, type: :text)

      assert %{"code" => "above_community"} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/rooms/#{room.id}/moderation", %{level: "full"})
               |> valid_response(400)
    end

    test "turns a room down", %{conn: conn, owner: owner, community: community} do
      room = TestUtils.get_room!(community, type: :text)

      assert %{"level" => "none", "effective" => "none"} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/rooms/#{room.id}/moderation", %{level: "none"})
               |> valid_response(200)
    end
  end

  describe "log" do
    test "returns 404 if private", %{conn: conn, owner: owner} do
      private = TestUtils.create_random_forum!(owner, visibility: :private)

      assert conn |> get(~p"/api/communities/#{private.id}/moderation/log") |> valid_response(404)
    end

    test "returns 404 if invite only", %{
      conn: conn,
      owner: owner
    } do
      community = TestUtils.create_random_forum!(owner, visibility: :invite_only)

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> get(~p"/api/communities/#{community.id}/moderation/log")
             |> valid_response(404)
    end

    test "shows who did what and why to anyone", %{
      conn: conn,
      owner: owner,
      author: author,
      community: community,
      item: item
    } do
      reason = Lorem.sentence()
      {:ok, _item} = Moderation.remove(owner, item, reason)

      assert %{"data" => [response]} =
               conn
               |> get(~p"/api/communities/#{community.id}/moderation/log")
               |> valid_response(200)

      assert %{"action" => "removed", "reason" => ^reason} = response
      assert response["actor"]["username"] == owner.username
      assert response["target"]["username"] == author.username
    end
  end
end
