defmodule HearthWeb.UserControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Accounts
  alias Hearth.Forum
  alias Hearth.Forum.Kind
  alias Hearth.TestUtils

  describe "index" do
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
      assert response["username"] == user.username
    end

    test "shows the profile", %{conn: conn} do
      user = TestUtils.register_random_user!()

      assert response = conn |> get(~p"/api/users/#{user.username}") |> valid_response(200)

      assert response["display_name"] == user.display_name
      assert response["links"] == []
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
      removed = TestUtils.create_random_post!(owner, open)
      {:ok, _removed} = Forum.moderate(removed, :removed)
      %{id: id} = TestUtils.create_random_post!(owner, open)

      assert %{"data" => [%{"id" => ^id, "reported" => false}]} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> get(~p"/api/users/#{owner.username}/posts")
               |> valid_response(200)
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
      post_id = post.id
      title = post.title

      assert %{"data" => [%{"reply" => %{"id" => _id}, "answer" => true, "post" => post}]} =
               conn |> get(~p"/api/users/#{author.username}/replies") |> valid_response(200)

      assert %{"id" => ^post_id, "title" => ^title} = post
    end
  end
end
