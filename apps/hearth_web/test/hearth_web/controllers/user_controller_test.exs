defmodule HearthWeb.UserControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Accounts
  alias Hearth.Forum
  alias Hearth.Forum.Kind
  alias Hearth.TestUtils
  alias HearthWeb.Presence

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)

    {:ok, binding()}
  end

  describe "index" do
    test "fails without signing in", %{conn: conn} do
      assert conn |> get(~p"/api/users") |> valid_response(401)
    end

    test "fails for a community that isn't an id", %{conn: conn, owner: owner} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/users?community=nope")
               |> valid_response(422)

      assert [_message] = errors["community"]
    end

    test "leaves out people with no community in common", %{conn: conn, owner: owner} do
      _stranger = TestUtils.join_random_member!(TestUtils.create_random_community!())

      assert [person] = conn |> auth_conn(owner) |> get(~p"/api/users") |> valid_response(200)
      refute person["id"] == owner.id
    end

    test "hides presence and communities when asked", %{conn: conn, owner: owner, member: member} do
      changes = %{presence: :nobody, last_seen: :nobody, show_communities: :nobody}
      {:ok, _privacy} = Accounts.update_privacy(member, changes)

      {:ok, _ref} = Presence.track_user(self(), member.id)

      assert [person] = conn |> auth_conn(owner) |> get(~p"/api/users") |> valid_response(200)
      assert %{"online" => false, "last_seen_at" => nil, "community_ids" => []} = person
    end

    test "lists people with the communities shared", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community
    } do
      {:ok, _ref} = Presence.track_user(self(), member.id)

      assert [person] = conn |> auth_conn(owner) |> get(~p"/api/users") |> valid_response(200)
      assert %{"online" => true, "community_ids" => [community_id]} = person
      assert person["id"] == member.id
      assert community_id == community.id
    end

    test "leaves out names with no account", %{conn: conn} do
      user = TestUtils.register_random_user!()

      assert [response] =
               conn
               |> get(~p"/api/users?#{%{usernames: "#{user.username},nobody_here"}}")
               |> valid_response(200)

      assert response["id"] == user.id
    end
  end

  describe "show" do
    test "returns 404 if missing", %{conn: conn} do
      assert conn |> get(~p"/api/users/nobody_here") |> valid_response(404)
    end

    test "hides a name the person chose not to show", %{conn: conn} do
      user = TestUtils.register_random_user!()
      {:ok, _privacy} = Accounts.update_privacy(user, %{show_name: false})

      assert response = conn |> get(~p"/api/users/#{user.username}") |> valid_response(200)

      assert response["display_name"] == nil
    end

    test "shows the profile", %{conn: conn} do
      user = TestUtils.register_random_user!()

      assert response = conn |> get(~p"/api/users/#{user.username}") |> valid_response(200)

      assert response["display_name"] == user.display_name
    end

    test "counts only what the reader may see", %{conn: conn} do
      owner = TestUtils.register_random_user!()
      open = TestUtils.create_random_forum!(owner)
      private = TestUtils.create_random_forum!(owner, visibility: :private)
      _post = TestUtils.create_random_post!(owner, open)
      _hidden = TestUtils.create_random_post!(owner, private)

      assert %{"counts" => %{"posts" => 1, "answers" => 0, "people_helped" => 0}} =
               conn |> get(~p"/api/users/#{owner.username}") |> valid_response(200)

      assert %{"counts" => %{"posts" => 2}} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/users/#{owner.username}")
               |> valid_response(200)
    end
  end

  describe "posts" do
    test "returns 404 if missing", %{conn: conn} do
      assert conn |> get(~p"/api/users/nobody_here/posts") |> valid_response(404)
    end

    test "leaves out hidden posts for outsider", %{conn: conn} do
      owner = TestUtils.register_random_user!()
      open = TestUtils.create_random_forum!(owner)
      private = TestUtils.create_random_forum!(owner, visibility: :private)
      _hidden = TestUtils.create_random_post!(owner, private)
      {:ok, _removed} = owner |> TestUtils.create_random_post!(open) |> Forum.moderate(:removed)
      shown = TestUtils.create_random_post!(owner, open)
      outsider = TestUtils.register_random_user!()

      assert %{"data" => [%{"reported" => false} = post]} =
               conn
               |> auth_conn(outsider)
               |> get(~p"/api/users/#{owner.username}/posts")
               |> valid_response(200)

      assert post["id"] == shown.id
    end
  end

  describe "replies" do
    test "returns 404 if missing", %{conn: conn} do
      assert conn |> get(~p"/api/users/nobody_here/replies") |> valid_response(404)
    end

    test "leaves out hidden replies", %{conn: conn} do
      owner = TestUtils.register_random_user!()
      private = TestUtils.create_random_forum!(owner, visibility: :private)
      post = TestUtils.create_random_post!(owner, private)
      {:ok, _reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      assert %{"data" => []} =
               conn |> get(~p"/api/users/#{owner.username}/replies") |> valid_response(200)
    end

    test "gives each reply with the post it answers", %{conn: conn} do
      owner = TestUtils.register_random_user!()
      community = TestUtils.create_random_forum!(owner)
      question = Kind.get(community_id: community.id, key: "question")
      post = TestUtils.create_random_post!(owner, community, kind_id: question.id)
      author = TestUtils.join_random_member!(community)
      {:ok, reply} = Forum.reply(author, post, %{body: Lorem.sentence()})
      {:ok, _post} = Forum.mark_answer(owner, post, reply)

      assert %{"data" => [%{"reply" => %{"id" => _id}, "answer" => true} = entry]} =
               conn |> get(~p"/api/users/#{author.username}/replies") |> valid_response(200)

      assert entry["post"]["id"] == post.id
      assert entry["post"]["title"] == post.title
    end
  end

  describe "available" do
    test "says a taken username isn't free", %{conn: conn} do
      user = TestUtils.register_random_user!()

      assert %{"available" => false} =
               conn
               |> get(~p"/api/users/available?#{%{username: user.username}}")
               |> valid_response(200)
    end

    test "says invalid username is not free", %{conn: conn} do
      assert %{"available" => false} =
               conn
               |> get(~p"/api/users/available?#{%{username: "No Spaces"}}")
               |> valid_response(200)
    end

    test "says a free username is free", %{conn: conn} do
      assert %{"available" => true} =
               conn
               |> get(~p"/api/users/available?#{%{username: TestUtils.random_username()}}")
               |> valid_response(200)
    end
  end
end
