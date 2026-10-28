defmodule HearthWeb.ShareCardControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Forum
  alias Hearth.Forum.Post
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, visibility: :public, template: "oss")
    hidden = TestUtils.create_random_community!(owner, visibility: :private, template: "oss")
    {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)
    {:ok, _kinds} = Forum.create_default_kinds(hidden.id, hidden.template)

    {:ok, binding()}
  end

  describe "community" do
    test "fails for a community that isn't public", %{conn: conn, hidden: hidden} do
      assert conn |> get(~p"/og/communities/#{hidden.slug}") |> response(404)
    end

    test "redirects to the card", %{conn: conn, community: community} do
      conn = get(conn, ~p"/og/communities/#{community.slug}")

      assert redirected_to(conn) =~ "/storage/cards/"
      assert get_resp_header(conn, "cache-control") == ["public, max-age=600"]
    end
  end

  describe "post" do
    test "fails if community not public", %{
      conn: conn,
      owner: owner,
      hidden: hidden
    } do
      post = TestUtils.create_random_post!(owner, hidden)

      assert conn |> get(~p"/og/posts/#{post.id}") |> response(404)
    end

    test "fails for a removed post", %{conn: conn, owner: owner, community: community} do
      post = TestUtils.create_random_post!(owner, community)
      :ok = TestUtils.update_rows!(Post, [id: post.id], status: :removed)

      assert conn |> get(~p"/og/posts/#{post.id}") |> response(404)
    end

    test "redirects to the card", %{conn: conn, owner: owner, community: community} do
      post = TestUtils.create_random_post!(owner, community)

      assert conn |> get(~p"/og/posts/#{post.id <> "-a-slug"}") |> redirected_to() =~
               "/storage/cards/"
    end
  end

  describe "event" do
    test "redirects to the card", %{conn: conn, owner: owner, community: community} do
      event = TestUtils.create_random_community_event!(owner, community)

      assert conn |> get(~p"/og/events/#{event.id}") |> redirected_to() =~ "/storage/cards/"
    end
  end

  describe "user" do
    test "fails for someone who doesn't exist", %{conn: conn} do
      assert conn |> get(~p"/og/users/#{TestUtils.random_username()}") |> response(404)
    end

    test "redirects to the card", %{conn: conn, owner: owner} do
      assert conn |> get(~p"/og/users/#{owner.username}") |> redirected_to() =~ "/storage/cards/"
    end
  end
end
