defmodule Hearth.Forum.SearchTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Forum
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner)
    reader = TestUtils.register_random_user!()

    {:ok, binding()}
  end

  describe "search_posts/3" do
    test "fails with a bad cursor", %{reader: reader} do
      assert {:error, :invalid_cursor} = Forum.search_posts(reader, "hydrating", after: "nope")
    end

    test "finds nothing without words", %{owner: owner, community: community} do
      _post = TestUtils.create_random_post!(owner, community, title: "Hydrating forms")

      assert %{data: []} = Forum.search_posts(owner, " ?! ")
    end

    test "leaves out private communities", %{owner: owner, reader: reader} do
      private = TestUtils.create_random_forum!(owner, visibility: :private)
      _post = TestUtils.create_random_post!(owner, private, title: "Hydrating forms")

      assert %{data: []} = Forum.search_posts(reader, "hydrating")
    end

    test "leaves out removed posts", %{owner: owner, reader: reader, community: community} do
      post = TestUtils.create_random_post!(owner, community, title: "Hydrating forms")
      {:ok, _post} = Forum.moderate(post, :removed)

      assert %{data: []} = Forum.search_posts(reader, "hydrating")
    end

    test "needs every word", %{owner: owner, reader: reader, community: community} do
      _post = TestUtils.create_random_post!(owner, community, title: "Hydrating forms")

      assert %{data: []} = Forum.search_posts(reader, "hydrating tables")
    end

    test "finds the start of a word", %{owner: owner, reader: reader, community: community} do
      post = TestUtils.create_random_post!(owner, community, title: "Hydrating forms")

      assert %{data: [%{post: %{id: id}, reply_id: nil}]} =
               Forum.search_posts(reader, "FORM hydr")

      assert id == post.id
    end

    test "shows the reply that matched", %{owner: owner, reader: reader, community: community} do
      post = TestUtils.create_random_post!(owner, community, title: Lorem.sentence())
      {:ok, reply} = Forum.reply(owner, post, %{body: "Try a zanzibar adapter instead"})

      assert %{data: [hit]} = Forum.search_posts(reader, "zanzibar")
      assert hit.reply_id == reply.id
      assert hit.excerpt == "Try a zanzibar adapter instead"
    end

    test "ranks a title above a body", %{owner: owner, reader: reader, community: community} do
      _body = TestUtils.create_random_post!(owner, community, body: "Hydrating forms is hard")
      title = TestUtils.create_random_post!(owner, community, title: "Hydrating forms")

      assert %{data: [%{post: %{id: id}} | _rest]} = Forum.search_posts(reader, "hydrating")
      assert id == title.id
    end

    test "pages with a cursor", %{owner: owner, reader: reader, community: community} do
      older = TestUtils.create_random_post!(owner, community, title: "Hydrating forms")
      _newer = TestUtils.create_random_post!(owner, community, title: "Hydrating tables")
      %{meta: meta} = Forum.search_posts(reader, "hydrating", limit: 1)

      assert %{data: [%{post: %{id: id}}], meta: %{has_next_page?: false}} =
               Forum.search_posts(reader, "hydrating", limit: 1, after: meta.end_cursor)

      assert id == older.id
    end

    test "keeps to one community", %{owner: owner, reader: reader, community: community} do
      other = TestUtils.create_random_forum!(owner)
      _post = TestUtils.create_random_post!(owner, other, title: "Hydrating forms")

      assert %{data: []} = Forum.search_posts(reader, "hydrating", community_id: community.id)
    end
  end

  describe "list_bookmarks/2" do
    test "leaves out deleted posts", %{owner: owner, reader: reader, community: community} do
      post = TestUtils.create_random_post!(owner, community)
      :ok = Forum.bookmark_post(reader, post, true)
      {:ok, _post} = Forum.delete_post(owner, post)

      assert %{data: []} = Forum.list_bookmarks(reader)
    end

    test "leaves out unsaved posts", %{owner: owner, reader: reader, community: community} do
      post = TestUtils.create_random_post!(owner, community)
      :ok = Forum.bookmark_post(reader, post, true)
      :ok = Forum.bookmark_post(reader, post, false)

      assert %{data: []} = Forum.list_bookmarks(reader)
    end

    test "lists newest saved first", %{owner: owner, reader: reader, community: community} do
      newer = TestUtils.create_random_post!(owner, community)
      older = TestUtils.create_random_post!(owner, community)
      :ok = Forum.bookmark_post(reader, older, true)
      :ok = Forum.bookmark_post(reader, newer, true)

      assert %{data: [%{id: id} | _rest]} = Forum.list_bookmarks(reader)
      assert id == newer.id
    end
  end

  describe "bookmarked/2" do
    test "is empty signed out", %{owner: owner, community: community} do
      post = TestUtils.create_random_post!(owner, community)

      assert Forum.bookmarked(nil, post) == MapSet.new()
    end

    test "saving twice keeps one", %{owner: owner, reader: reader, community: community} do
      post = TestUtils.create_random_post!(owner, community)
      :ok = Forum.bookmark_post(reader, post, true)
      :ok = Forum.bookmark_post(reader, post, true)

      assert Forum.bookmarked(reader, post) == MapSet.new([post.id])
    end
  end
end
