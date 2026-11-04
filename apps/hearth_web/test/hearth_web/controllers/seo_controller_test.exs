defmodule HearthWeb.SeoControllerTest do
  # Switching indexing off changes the application environment.
  use HearthWeb.ConnCase, async: false

  alias Hearth.Forum
  alias Hearth.Forum.Post
  alias Hearth.Notifications
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()

    indexed =
      TestUtils.create_random_community!(owner, visibility: :public_indexed, template: "oss")

    listed = TestUtils.create_random_community!(owner, visibility: :public)
    community = TestUtils.create_random_community!(owner, visibility: :public, template: "oss")
    hidden = TestUtils.create_random_community!(owner, visibility: :private, template: "oss")
    {:ok, _kinds} = Forum.create_default_kinds(indexed.id, indexed.template)
    {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)
    {:ok, _kinds} = Forum.create_default_kinds(hidden.id, hidden.template)

    {:ok, binding()}
  end

  describe "robots" do
    test "blocks everything when indexing is off", %{conn: conn} do
      :ok = TestUtils.put_env(:instance_indexing, false)

      assert conn |> get(~p"/robots.txt") |> response(200) == "User-agent: *\nDisallow: /\n"
    end

    test "points crawlers at the sitemap", %{conn: conn} do
      body = conn |> get(~p"/robots.txt") |> response(200)

      assert body =~ "Disallow: /settings\n"
      assert body =~ "Sitemap: " <> Notifications.url("/sitemap.xml")
    end
  end

  describe "sitemap" do
    test "lists nothing when indexing is off", %{conn: conn, indexed: indexed} do
      :ok = TestUtils.put_env(:instance_indexing, false)

      refute conn |> get(~p"/sitemap.xml") |> response(200) =~ indexed.slug
    end

    test "lists only indexed communities", %{conn: conn, indexed: indexed, listed: listed} do
      conn = get(conn, ~p"/sitemap.xml")
      body = response(conn, 200)

      assert get_resp_header(conn, "content-type") == ["application/xml; charset=utf-8"]
      assert body =~ Notifications.url("/sitemaps/#{indexed.slug}.xml")
      refute body =~ "/sitemaps/#{listed.slug}.xml"
    end
  end

  describe "sitemap_file" do
    test "fails for a community that is not indexed", %{conn: conn, listed: listed} do
      assert conn |> get(~p"/sitemaps/#{listed.slug <> ".xml"}") |> response(404)
    end

    test "fails for a page past the last", %{conn: conn, indexed: indexed} do
      assert conn |> get(~p"/sitemaps/#{indexed.slug <> ".2.xml"}") |> response(404)
    end

    test "lists community events and posts", %{
      conn: conn,
      owner: owner,
      indexed: indexed
    } do
      post = TestUtils.create_random_post!(owner, indexed)
      removed = TestUtils.create_random_post!(owner, indexed)
      event = TestUtils.create_random_community_event!(owner, indexed)
      :ok = TestUtils.update_rows!(Post, [id: removed.id], status: :removed)

      body = conn |> get(~p"/sitemaps/#{indexed.slug <> ".xml"}") |> response(200)

      assert body =~ "<loc>" <> Notifications.url("/c/#{indexed.slug}") <> "</loc>"
      assert body =~ "/c/#{indexed.slug}/e/#{event.id}"
      assert body =~ "/c/#{indexed.slug}/p/#{post.id}"
      assert body =~ "<lastmod>"
      refute body =~ removed.id
    end
  end

  describe "og_community" do
    test "fails for a community that isn't public", %{conn: conn, hidden: hidden} do
      assert conn |> get(~p"/og/communities/#{hidden.slug}") |> response(404)
    end

    test "redirects to the card", %{conn: conn, community: community} do
      conn = get(conn, ~p"/og/communities/#{community.slug}")

      assert redirected_to(conn) =~ "/storage/cards/"
      assert get_resp_header(conn, "cache-control") == ["public, max-age=600"]
    end
  end

  describe "og_post" do
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

  describe "og_event" do
    test "redirects to the card", %{conn: conn, owner: owner, community: community} do
      event = TestUtils.create_random_community_event!(owner, community)

      assert conn |> get(~p"/og/events/#{event.id}") |> redirected_to() =~ "/storage/cards/"
    end
  end

  describe "og_user" do
    test "fails for someone who doesn't exist", %{conn: conn} do
      assert conn |> get(~p"/og/users/#{TestUtils.random_username()}") |> response(404)
    end

    test "redirects to the card", %{conn: conn, owner: owner} do
      assert conn |> get(~p"/og/users/#{owner.username}") |> redirected_to() =~ "/storage/cards/"
    end
  end
end
