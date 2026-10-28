defmodule HearthWeb.ReplyControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.TestUtils

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
    test "returns 404 if post is invite only", %{
      conn: conn,
      owner: owner
    } do
      community = TestUtils.create_random_forum!(owner, visibility: :invite_only)
      post = TestUtils.create_random_post!(owner, community)

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> get(~p"/api/posts/#{post.id}/replies")
             |> valid_response(404)
    end

    test "returns 404 for a parent from another post", %{conn: conn, owner: owner, post: post} do
      assert conn
             |> auth_conn(owner)
             |> get(~p"/api/posts/#{post.id}/replies?parent_id=#{Common.new_id()}")
             |> valid_response(404)
    end

    test "lists top level then branch", %{
      conn: conn,
      owner: owner,
      member: member,
      post: post
    } do
      {:ok, top} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      {:ok, answer} =
        Forum.reply(member, post, %{body: Lorem.sentence(), parent_reply_id: top.id})

      assert %{"data" => [entry]} =
               conn |> get(~p"/api/posts/#{post.id}/replies") |> valid_response(200)

      assert entry["id"] == top.id
      assert entry["child_count"] == 1

      assert %{"data" => [child]} =
               conn
               |> get(~p"/api/posts/#{post.id}/replies?parent_id=#{top.id}")
               |> valid_response(200)

      assert child["body"] == answer.body
      assert child["depth"] == 1
    end
  end

  describe "create" do
    test "fails due to validation", %{conn: conn, member: member, post: post} do
      body = %{body: ""}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/posts/#{post.id}/replies", body)
               |> valid_response(422)

      assert [_message] = errors["body"]
    end

    test "fails on a locked post", %{conn: conn, owner: owner, member: member, post: post} do
      {:ok, _post} = Forum.lock_post(owner, post, true)

      assert %{"code" => "locked"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/posts/#{post.id}/replies", %{body: Lorem.sentence()})
               |> valid_response(400)
    end

    test "replies to a post", %{conn: conn, owner: owner, post: post} do
      body = %{body: Lorem.sentence()}

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/posts/#{post.id}/replies", body)
               |> valid_response(201)

      assert response["body"] == body.body
      assert response["depth"] == 0
      assert response["author"]["id"] == owner.id
    end
  end

  describe "update" do
    test "fails if not the author", %{conn: conn, owner: owner, member: member, post: post} do
      {:ok, reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/replies/#{reply.id}", %{body: Lorem.sentence()})
               |> valid_response(403)
    end

    test "fails with more than 10 files", %{conn: conn, owner: owner, post: post} do
      {:ok, reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      body = %{
        body: Lorem.sentence(),
        attachment_ids: TestUtils.random_ids(11)
      }

      assert %{"code" => "too_many_attachments"} =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/replies/#{reply.id}", body)
               |> valid_response(400)
    end

    test "edits a reply", %{conn: conn, owner: owner, post: post} do
      {:ok, reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})
      body = %{body: Lorem.sentence()}

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/replies/#{reply.id}", body)
               |> valid_response(200)

      assert response["body"] == body.body
    end
  end

  describe "delete" do
    test "keeps a deleted reply that has answers", %{
      conn: conn,
      owner: owner,
      member: member,
      post: post
    } do
      {:ok, top} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      {:ok, _answer} =
        Forum.reply(member, post, %{body: Lorem.sentence(), parent_reply_id: top.id})

      assert conn |> auth_conn(owner) |> delete(~p"/api/replies/#{top.id}") |> response(204)

      assert %{"data" => [%{"deleted" => true, "body" => nil, "author" => nil}]} =
               conn |> get(~p"/api/posts/#{post.id}/replies") |> valid_response(200)
    end
  end

  describe "helpful" do
    test "marks a reply as helpful", %{conn: conn, owner: owner, member: member, post: post} do
      {:ok, reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      assert %{"on" => true} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/replies/#{reply.id}/helpful")
               |> valid_response(200)
    end
  end
end
