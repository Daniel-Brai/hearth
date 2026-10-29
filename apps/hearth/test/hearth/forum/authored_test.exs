defmodule Hearth.Forum.AuthoredTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Forum.Kind
  alias Hearth.Forum.Post
  alias Hearth.Forum.Reply
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner)
    author = TestUtils.join_random_member!(community)
    reader = TestUtils.join_random_member!(community)
    question = Kind.get(community_id: community.id, key: "question")

    {:ok, binding()}
  end

  describe "author_counts/2" do
    test "counts nothing outside the communities given", %{author: author, community: community} do
      _post = TestUtils.create_random_post!(author, community)

      assert %{posts: 0, answers: 0, people_helped: 0} = Forum.author_counts(author.id, [])
    end

    test "leaves out hidden posts", %{author: author, community: community} do
      removed = TestUtils.create_random_post!(author, community)
      {:ok, _post} = Forum.moderate(removed, :removed)
      held = TestUtils.create_random_post!(author, community)
      {:ok, _post} = Forum.moderate(held, :pending)
      deleted = TestUtils.create_random_post!(author, community)
      {:ok, _post} = Forum.delete_post(author, deleted)

      assert %{posts: 0} = Forum.author_counts(author.id, [community.id])
    end

    test "counts posts answers and helped", %{
      owner: owner,
      author: author,
      reader: reader,
      community: community,
      question: question
    } do
      post = TestUtils.create_random_post!(author, community)
      asked = TestUtils.create_random_post!(owner, community, kind_id: question.id)
      {:ok, answer} = Forum.reply(author, asked, %{body: Lorem.sentence()})
      {:ok, _asked} = Forum.mark_answer(owner, asked, answer)
      {:ok, _on} = Forum.toggle_helpful(reader, post)
      {:ok, _on} = Forum.toggle_helpful(reader, answer)
      {:ok, _on} = Forum.toggle_helpful(owner, answer)

      assert %{posts: 1, answers: 1, people_helped: 2} =
               Forum.author_counts(author.id, [community.id])
    end
  end

  describe "list_author_posts/3" do
    test "leaves out other communities and removed", %{
      author: author,
      community: community
    } do
      removed = TestUtils.create_random_post!(author, community)
      {:ok, _post} = Forum.moderate(removed, :removed)
      _elsewhere = TestUtils.create_random_post!(author, community)

      assert %Page{data: []} = Forum.list_author_posts(author.id, [])

      assert %Page{data: [%Post{status: :published}]} =
               Forum.list_author_posts(author.id, [community.id])
    end

    test "lists the newest first", %{author: author, community: community} do
      _older = TestUtils.create_random_post!(author, community)
      newest = TestUtils.create_random_post!(author, community)

      assert %Page{data: [latest | _rest]} = Forum.list_author_posts(author.id, [community.id])
      assert latest.id == newest.id
    end
  end

  describe "list_author_replies/3" do
    test "leaves out other communities and removed", %{
      owner: owner,
      author: author,
      community: community
    } do
      post = TestUtils.create_random_post!(owner, community)
      {:ok, removed} = Forum.reply(author, post, %{body: Lorem.sentence()})
      {:ok, _reply} = Forum.moderate(removed, :removed)
      {:ok, _kept} = Forum.reply(author, post, %{body: Lorem.sentence()})

      assert %Page{data: []} = Forum.list_author_replies(author.id, [])

      assert %Page{data: [%Reply{status: :published}]} =
               Forum.list_author_replies(author.id, [community.id])
    end

    test "leaves out replies on a removed post", %{
      owner: owner,
      author: author,
      community: community
    } do
      post = TestUtils.create_random_post!(owner, community)
      {:ok, _reply} = Forum.reply(author, post, %{body: Lorem.sentence()})
      {:ok, _post} = Forum.moderate(post, :removed)

      assert %Page{data: []} = Forum.list_author_replies(author.id, [community.id])
    end

    test "lists the newest first", %{owner: owner, author: author, community: community} do
      post = TestUtils.create_random_post!(owner, community)
      {:ok, _older} = Forum.reply(author, post, %{body: Lorem.sentence()})
      {:ok, newest} = Forum.reply(author, post, %{body: Lorem.sentence()})

      assert %Page{data: [latest | _rest]} = Forum.list_author_replies(author.id, [community.id])
      assert latest.id == newest.id
    end
  end

  describe "list_posts_by_id/1" do
    test "gives each post by id", %{author: author, community: community} do
      post = TestUtils.create_random_post!(author, community)

      assert %{} = posts = Forum.list_posts_by_id([post.id])
      assert posts[post.id].id == post.id
    end
  end

  describe "Communities.readable_ids/1" do
    test "leaves out hidden communities for outsiders", %{
      owner: owner,
      community: community
    } do
      invite = TestUtils.create_random_community!(owner, visibility: :invite_only)
      private = TestUtils.create_random_community!(owner, visibility: :private)
      outsider = TestUtils.register_random_user!()

      ids = Communities.readable_ids(outsider)

      assert community.id in ids
      refute invite.id in ids
      refute private.id in ids
      assert ids == Communities.readable_ids(nil)
    end

    test "adds the private communities the reader is in", %{owner: owner} do
      private = TestUtils.create_random_community!(owner, visibility: :private)

      assert private.id in Communities.readable_ids(owner)
    end
  end
end
