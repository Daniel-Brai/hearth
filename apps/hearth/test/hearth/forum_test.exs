defmodule Hearth.ForumTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Chat.Message
  alias Hearth.Chat.MessageCreated
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Forum.AnswerMarked
  alias Hearth.Forum.Draft
  alias Hearth.Forum.Kind
  alias Hearth.Forum.Post
  alias Hearth.Forum.PostCreated
  alias Hearth.Forum.PostReacted
  alias Hearth.Forum.PostRead
  alias Hearth.Forum.Reply
  alias Hearth.Forum.ReplyCreated
  alias Hearth.Media
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    :ok = Forum.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)

    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)

    kinds =
      community.id
      |> Forum.list_kinds()
      |> Map.new(&{&1.key, &1})

    {:ok, binding()}
  end

  describe "create_default_kinds/2" do
    test "fails if the community already has them", %{community: community} do
      assert {:error, changeset} = Forum.create_default_kinds(community.id, "oss")
      assert %{key: ["has already been taken"]} = errors_on(changeset)
    end

    test "create default kinds", %{kinds: kinds} do
      assert %{
               "announcement" => %Kind{},
               "bug" => %Kind{},
               "discussion" => %Kind{},
               "idea" => %Kind{},
               "question" => %Kind{},
               "show" => %Kind{}
             } = kinds

      assert map_size(kinds) == 6

      assert %Kind{answers: true} = kinds["question"]
      assert %Kind{postable: false} = kinds["announcement"]
    end
  end

  describe "create_post/3" do
    test "fails if not a member", %{community: community, kinds: kinds} do
      params = %{kind_id: kinds["question"].id, title: Lorem.sentence()}

      assert {:error, :forbidden} =
               Forum.create_post(TestUtils.register_random_user!(), community, params)
    end

    test "fails if kind belongs to another community", %{member: member, community: community} do
      other = TestUtils.create_random_community!()
      {:ok, [kind | _kinds]} = Forum.create_default_kinds(other.id, "blank")

      assert {:error, :unknown_kind} =
               Forum.create_post(member, community, %{kind_id: kind.id, title: Lorem.sentence()})
    end

    test "fails if kind is for moderators", %{member: member, community: community, kinds: kinds} do
      params = %{kind_id: kinds["announcement"].id, title: Lorem.sentence()}

      assert {:error, :forbidden} = Forum.create_post(member, community, params)
    end

    test "fails if title is missing", %{member: member, community: community, kinds: kinds} do
      assert {:error, changeset} =
               Forum.create_post(member, community, %{kind_id: kinds["question"].id, title: " "})

      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails if title is over 150 characters", %{
      member: member,
      community: community,
      kinds: kinds
    } do
      params = %{kind_id: kinds["question"].id, title: String.duplicate("a", 151)}

      assert {:error, changeset} = Forum.create_post(member, community, params)
      assert %{title: ["should be at most 150 character(s)"]} = errors_on(changeset)
    end

    test "create post", %{member: member, community: community, kinds: kinds} do
      %{id: author_id} = member

      params = %{
        kind_id: kinds["question"].id,
        title: Lorem.sentence(),
        body: "#{Lorem.sentence()} Tagged #Turbo-8 and #morphing"
      }

      assert {:ok, %Post{} = post} = Forum.create_post(member, community, params)
      assert post.author_id == member.id
      assert TestUtils.pluck(post.tags, :name) == ~w[turbo-8 morphing]
      assert_receive %PostCreated{author_id: ^author_id}
    end
  end

  describe "promote/4" do
    setup %{community: community} do
      room = TestUtils.get_room!(community, type: :text)

      {:ok, binding()}
    end

    test "fails without chat.promote", %{member: member, room: room, kinds: kinds} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      params = %{kind_id: kinds["question"].id, title: Lorem.sentence()}

      assert {:error, :forbidden} = Forum.promote(member, room, [message.id], params)
    end

    test "fails in a private room", %{owner: owner, community: community, kinds: kinds} do
      room = TestUtils.create_random_private_room!(community, ["moderator"])
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      params = %{kind_id: kinds["question"].id, title: Lorem.sentence()}

      assert {:error, :private_room} = Forum.promote(owner, room, [message.id], params)
    end

    test "fails with no messages", %{owner: owner, room: room, kinds: kinds} do
      params = %{kind_id: kinds["question"].id, title: Lorem.sentence()}

      assert {:error, :invalid_messages} = Forum.promote(owner, room, [], params)
    end

    test "fails for a message from another room", %{
      owner: owner,
      member: member,
      community: community,
      room: room,
      kinds: kinds
    } do
      other = TestUtils.get_room!(community, slug: "help")
      {:ok, message} = Chat.send_message(member, other, %{body: Lorem.sentence()})
      params = %{kind_id: kinds["question"].id, title: Lorem.sentence()}

      assert {:error, :invalid_messages} = Forum.promote(owner, room, [message.id], params)
    end

    test "fails if title is missing", %{owner: owner, member: member, room: room, kinds: kinds} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      params = %{kind_id: kinds["question"].id, title: " "}

      assert {:error, changeset} = Forum.promote(owner, room, [message.id], params)
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "promote messages", %{owner: owner, member: member, room: room, kinds: kinds} do
      :ok = Chat.subscribe_to_pubsub()
      %{id: owner_id} = owner

      {:ok, first} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, second} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      [file] = TestUtils.upload_random_attachments!(member, 1)
      {:ok, third} = Chat.send_message(member, room, %{body: "", attachment_ids: [file.id]})

      params = %{kind_id: kinds["question"].id, title: Lorem.sentence()}
      ids = [third.id, first.id, second.id]

      assert {:ok, %Post{} = post} = Forum.promote(owner, room, ids, params)
      assert post.author_id == member.id
      assert post.promoted_by_id == owner.id
      assert post.body == first.body

      %Page{data: [_second, files_reply]} = Forum.list_replies(post)

      assert [attachment] = Media.list_attachments(:reply, [files_reply.id])[files_reply.id]
      assert attachment.media_id == file.id

      second_id = second.id

      assert_receive %MessageCreated{author_id: ^owner_id, message_id: notice_id}
                     when notice_id != second_id

      assert {:ok, %Message{kind: :promoted, post_id: post_id}} = Chat.get_message(notice_id)
      assert post_id == post.id
    end
  end

  describe "update_post/3" do
    test "fails if not the author", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert {:error, :forbidden} = Forum.update_post(owner, post, %{title: Lorem.sentence()})
    end

    test "keeps the files when none are sent", %{member: member, community: community} do
      [file] = TestUtils.upload_random_attachments!(member, 1)
      post = TestUtils.create_random_post!(member, community, attachment_ids: [file.id])

      assert {:ok, _updated} = Forum.update_post(member, post, %{title: Lorem.sentence()})
      assert [attachment] = Media.list_attachments(:post, [post.id])[post.id]
      assert attachment.media_id == file.id
    end

    test "update post", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      params = %{title: Lorem.sentence(), body: "#{Lorem.sentence()} #tagged"}

      assert {:ok, %Post{edited_at: %DateTime{}, tags: [%{name: "tagged"}]} = updated} =
               Forum.update_post(member, post, params)

      assert updated.title == params.title
    end
  end

  describe "delete_post/2" do
    test "fails if not the author", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(owner, community)

      assert {:error, :forbidden} = Forum.delete_post(member, post)
    end

    test "fails if user can moderate", %{
      owner: owner,
      member: member,
      community: community
    } do
      post = TestUtils.create_random_post!(member, community)

      assert {:error, :forbidden} = Forum.delete_post(owner, post)
    end

    test "delete post", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert {:ok, %Post{deleted_at: %DateTime{}}} = Forum.delete_post(member, post)
      assert {:error, :not_found} = Forum.get_post(id: post.id)
    end
  end

  describe "pin_post/3" do
    test "fails if not allowed", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert {:error, :forbidden} = Forum.pin_post(member, post, true)
    end

    test "pin post", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      other = TestUtils.create_random_post!(member, community)

      assert {:ok, %Post{pinned_at: %DateTime{}}} = Forum.pin_post(owner, post, true)
      assert [pinned] = Forum.list_pinned(community)
      assert pinned.id == post.id
      assert %Page{data: [listed]} = Forum.list_posts(community)
      assert listed.id == other.id
    end
  end

  describe "reply/3" do
    test "fails with more than 10 files", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      ids = TestUtils.random_ids(11)

      assert {:error, :too_many_attachments} =
               Forum.reply(member, post, %{body: Lorem.sentence(), attachment_ids: ids})
    end

    test "fails if not a member", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert {:error, :forbidden} =
               Forum.reply(TestUtils.register_random_user!(), post, %{body: Lorem.sentence()})
    end

    test "fails if post is locked", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      {:ok, locked} = Forum.lock_post(owner, post, true)

      assert {:error, :locked} = Forum.reply(member, locked, %{body: Lorem.sentence()})
    end

    test "fails if parent is on another post", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      other_post = TestUtils.create_random_post!(member, community)
      {:ok, reply} = Forum.reply(member, other_post, %{body: Lorem.sentence()})

      assert {:error, :not_found} =
               Forum.reply(member, post, %{body: Lorem.sentence(), parent_reply_id: reply.id})
    end

    test "fails if body is missing", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert {:error, changeset} = Forum.reply(member, post, %{body: ""})
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "sends files with no text", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      [file] = TestUtils.upload_random_attachments!(member, 1)
      params = %{body: "", attachment_ids: [file.id]}

      assert {:ok, reply} = Forum.reply(member, post, params)
      assert [attachment] = Media.list_attachments(:reply, [reply.id])[reply.id]
      assert attachment.media_id == file.id
    end

    test "reply to post", %{owner: owner, member: member, community: community} do
      %{id: post_author_id} = member
      post = TestUtils.create_random_post!(member, community)

      assert {:ok, %Reply{depth: 0}} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      assert {:ok, %Post{reply_count: 1}} = Forum.get_post(id: post.id)
      assert_receive %ReplyCreated{post_author_id: ^post_author_id}
    end

    test "nest replies and count them", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      {:ok, top} = Forum.reply(member, post, %{body: Lorem.sentence()})
      {:ok, child} = Forum.reply(owner, post, %{body: Lorem.sentence(), parent_reply_id: top.id})

      assert {:ok, %Reply{depth: 2} = grandchild} =
               Forum.reply(member, post, %{body: Lorem.sentence(), parent_reply_id: child.id})

      assert grandchild.root_reply_id == top.id
      assert grandchild.path == [top.id, child.id]

      assert %Reply{child_count: 1, descendant_count: 2} = parent = Reply.get(id: top.id)
      assert parent.recent_repliers == [member.id, owner.id]
      assert %Reply{child_count: 1, descendant_count: 1} = Reply.get(id: child.id)
    end

    test "keeps replies at the deepest level beside it", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      {:ok, top} = Forum.reply(member, post, %{body: Lorem.sentence()})

      assert %Reply{depth: 10} =
               deepest = TestUtils.create_random_reply_chain!(member, post, top, 10)

      assert {:ok, %Reply{depth: 10} = reply} =
               Forum.reply(member, post, %{body: Lorem.sentence(), parent_reply_id: deepest.id})

      assert reply.parent_reply_id == deepest.parent_reply_id
    end
  end

  describe "list_replies/2" do
    test "list one level", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      {:ok, plain} = Forum.reply(owner, post, %{body: Lorem.sentence()})
      {:ok, helpful} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      params = %{body: Lorem.sentence(), parent_reply_id: plain.id}
      {:ok, nested} = Forum.reply(member, post, params)

      {:ok, :marked} = Forum.toggle_helpful(member, helpful)

      %Page{data: replies} = Forum.list_replies(post)

      assert TestUtils.pluck(replies, :id) == [helpful.id, plain.id]
      assert %Page{data: [child]} = Forum.list_replies(post, parent: plain)
      assert child.id == nested.id
    end
  end

  describe "delete_reply/2" do
    test "fails if not the author", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      {:ok, reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      assert {:error, :forbidden} = Forum.delete_reply(member, reply)
    end

    test "fails if user can moderate", %{
      owner: owner,
      member: member,
      community: community
    } do
      post = TestUtils.create_random_post!(member, community)
      {:ok, reply} = Forum.reply(member, post, %{body: Lorem.sentence()})

      assert {:error, :forbidden} = Forum.delete_reply(owner, reply)
    end

    test "keeps a reply that has answers", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      {:ok, top} = Forum.reply(member, post, %{body: Lorem.sentence()})
      {:ok, _child} = Forum.reply(owner, post, %{body: Lorem.sentence(), parent_reply_id: top.id})
      {:ok, reply} = Forum.get_reply(top.id)

      assert {:ok, %Reply{deleted_at: %DateTime{}}} = Forum.delete_reply(member, reply)
      assert Reply.exists?(id: top.id)
    end

    test "removes a reply with no answers", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      {:ok, top} = Forum.reply(member, post, %{body: Lorem.sentence()})
      {:ok, child} = Forum.reply(owner, post, %{body: Lorem.sentence(), parent_reply_id: top.id})

      assert {:ok, _reply} = Forum.delete_reply(owner, child)
      refute Reply.exists?(id: child.id)
      assert {:ok, %Reply{child_count: 0, descendant_count: 0}} = Forum.get_reply(top.id)
      assert {:ok, %Post{reply_count: 1}} = Forum.get_post(id: post.id)
    end
  end

  describe "mark_answer/3" do
    test "fails if not allowed", %{
      owner: owner,
      member: member,
      community: community,
      kinds: kinds
    } do
      post = TestUtils.create_random_post!(owner, community, kind_id: kinds["question"].id)
      {:ok, reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      assert {:error, :forbidden} = Forum.mark_answer(member, post, reply)
    end

    test "fails if the kind takes no answers", %{
      member: member,
      community: community,
      kinds: kinds
    } do
      post = TestUtils.create_random_post!(member, community, kind_id: kinds["discussion"].id)
      {:ok, reply} = Forum.reply(member, post, %{body: Lorem.sentence()})

      assert {:error, :no_answers} = Forum.mark_answer(member, post, reply)
    end

    test "author marks the answer", %{
      owner: owner,
      member: member,
      community: community,
      kinds: kinds
    } do
      post = TestUtils.create_random_post!(member, community, kind_id: kinds["question"].id)
      {:ok, %{id: reply_id} = reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      assert {:ok, %Post{} = answered} = Forum.mark_answer(member, post, reply)
      assert answered.answer_reply_id == reply.id
      assert_receive %AnswerMarked{reply_id: ^reply_id}
    end
  end

  describe "toggle_reaction/3" do
    test "fails if emoji is too long", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert {:error, :invalid_emoji} =
               Forum.toggle_reaction(owner, post, String.duplicate("x", 9))
    end

    test "toggle reaction", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)
      %{id: id} = post

      assert {:ok, :added} = Forum.toggle_reaction(owner, post, "🔥")
      assert_receive %PostReacted{post_id: ^id, emoji: "🔥", on: true, count: 1}

      assert {:ok, :removed} = Forum.toggle_reaction(owner, post, "🔥")
      assert_receive %PostReacted{post_id: ^id, emoji: "🔥", on: false, count: 0}
    end
  end

  describe "list_reactions/2" do
    test "returns nothing for posts nobody reacted to", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert %{} == Forum.list_reactions(member, [post])
    end

    test "counts each emoji and marks the viewer's own", %{
      owner: owner,
      member: member,
      community: community
    } do
      post = TestUtils.create_random_post!(member, community)
      {:ok, :added} = Forum.toggle_reaction(owner, post, "🔥")
      {:ok, :added} = Forum.toggle_reaction(member, post, "🔥")
      {:ok, :added} = Forum.toggle_reaction(owner, post, "👍")

      assert %{
               post.id => [
                 %{emoji: "🔥", count: 2, mine: true},
                 %{emoji: "👍", count: 1, mine: false}
               ]
             } ==
               Forum.list_reactions(member, [post])

      assert %{
               post.id => [
                 %{emoji: "🔥", count: 2, mine: false},
                 %{emoji: "👍", count: 1, mine: false}
               ]
             } ==
               Forum.list_reactions(nil, [post])
    end
  end

  describe "toggle_helpful/2" do
    test "fails if own post", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert {:error, :own} = Forum.toggle_helpful(member, post)
    end

    test "toggle helpful", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert {:ok, :marked} = Forum.toggle_helpful(owner, post)
      assert {:ok, %Post{helpful_count: 1}} = Forum.get_post(id: post.id)
      assert {:ok, :unmarked} = Forum.toggle_helpful(owner, post)
      assert {:ok, %Post{helpful_count: 0}} = Forum.get_post(id: post.id)
    end
  end

  describe "mark_seen/2" do
    test "mark seen", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert :ok = Forum.mark_seen(owner, post)
      assert %PostRead{seen_reply_count: 0} = PostRead.get(user_id: owner.id)
    end
  end

  describe "seen/2" do
    test "sees nothing signed out", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert MapSet.new() == Forum.seen(nil, [post])
    end

    test "lists the posts read", %{owner: owner, member: member, community: community} do
      read = TestUtils.create_random_post!(member, community)
      unread = TestUtils.create_random_post!(member, community)
      :ok = Forum.mark_seen(owner, read)

      assert MapSet.new([read.id]) == Forum.seen(owner, [read, unread])
    end
  end

  describe "mark_all_seen/2" do
    test "fails if not in private community", %{owner: owner} do
      private = TestUtils.create_random_community!(owner, visibility: :private)

      assert {:error, :not_found} =
               Forum.mark_all_seen(TestUtils.register_random_user!(), private)
    end

    test "mark a community seen", %{owner: owner, member: member, community: community} do
      older = TestUtils.create_random_post!(member, community)
      newer = TestUtils.create_random_post!(member, community)

      assert :ok = Forum.mark_all_seen(owner, community)
      assert MapSet.new([older.id, newer.id]) == Forum.seen(owner, [older, newer])
    end

    test "mark every joined community seen", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(owner, community)

      assert :ok = Forum.mark_all_seen(member, nil)
      assert MapSet.new([post.id]) == Forum.seen(member, [post])
    end
  end

  describe "watch_post/3" do
    test "nobody watches signed out", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert MapSet.new() == Forum.watched(nil, post)
    end

    test "a post's author watches it", %{member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert MapSet.new([post.id]) == Forum.watched(member, post)
      assert [member.id] == Forum.watcher_ids(post.id)
    end

    test "replying keeps a choice to stop", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert :ok = Forum.watch_post(member, post, false)
      assert {:ok, _reply} = Forum.reply(member, post, %{body: Lorem.sentence()})
      assert MapSet.new() == Forum.watched(member, post)
      assert {:ok, _reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})
      assert [owner.id] == Forum.watcher_ids(post.id)
    end

    test "watch and stop", %{owner: owner, member: member, community: community} do
      post = TestUtils.create_random_post!(member, community)

      assert :ok = Forum.watch_post(owner, post, true)
      assert MapSet.new([post.id]) == Forum.watched(owner, [post])
      assert :ok = Forum.watch_post(owner, post, false)
      assert MapSet.new() == Forum.watched(owner, [post])
    end
  end

  describe "list_drafts/1" do
    test "lists only my drafts", %{owner: owner, member: member, community: community} do
      {:ok, mine} = Forum.save_draft(member, community, %{title: Lorem.sentence()})
      {:ok, _theirs} = Forum.save_draft(owner, community, %{title: Lorem.sentence()})

      assert [%Draft{} = draft] = Forum.list_drafts(member)
      assert draft.id == mine.id
    end
  end

  describe "save_draft/3" do
    test "fails if not a member", %{community: community} do
      user = TestUtils.register_random_user!()

      assert {:error, :forbidden} = Forum.save_draft(user, community, %{title: Lorem.sentence()})
    end

    test "fails if title is over 150 characters", %{member: member, community: community} do
      assert {:error, changeset} =
               Forum.save_draft(member, community, %{title: String.duplicate("a", 151)})

      assert %{title: ["should be at most 150 character(s)"]} = errors_on(changeset)
    end

    test "save and discard draft", %{member: member, community: community} do
      params = %{title: Lorem.sentence()}

      assert {:ok, %Draft{}} = Forum.save_draft(member, community, %{title: Lorem.sentence()})
      assert {:ok, %Draft{} = draft} = Forum.save_draft(member, community, params)
      assert draft.title == params.title
      assert :ok = Forum.discard_draft(member, community)
      refute Forum.get_draft(member, community)
    end
  end
end
