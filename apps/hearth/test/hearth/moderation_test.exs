defmodule Hearth.ModerationTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Communities
  alias Hearth.Communities.Ban
  alias Hearth.Forum
  alias Hearth.Moderation
  alias Hearth.Moderation.Action
  alias Hearth.Moderation.ContentRemoved
  alias Hearth.Moderation.ContentRestored
  alias Hearth.Moderation.Item
  alias Hearth.Moderation.ItemQueued
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner, moderation: :reports)
    member = TestUtils.join_random_member!(community)
    author = TestUtils.join_random_member!(community)
    post = TestUtils.create_random_post!(author, community)
    :ok = Moderation.subscribe_to_pubsub()

    {:ok, binding()}
  end

  describe "level/2" do
    test "follows the community without a room", %{community: community} do
      assert Moderation.level(community, nil) == :reports
    end

    test "takes the lower of the community and the room", %{community: community} do
      room = TestUtils.get_room!(community, type: :text)

      assert Moderation.level(community, %{room | moderation: :none}) == :none
      assert Moderation.level(community, %{room | moderation: :full}) == :reports
    end
  end

  describe "set_level/3" do
    test "fails without community.update", %{
      member: member,
      community: community
    } do
      assert {:error, :forbidden} = Moderation.set_level(member, community, :full)
    end

    test "fails for a room without room.update", %{member: member, community: community} do
      room = TestUtils.get_room!(community, type: :text)

      assert {:error, :forbidden} = Moderation.set_level(member, room, :none)
    end

    test "fails for a room above its community", %{owner: owner, community: community} do
      room = TestUtils.get_room!(community, type: :text)

      assert {:error, :above_community} = Moderation.set_level(owner, room, :full)
    end

    test "succeeds with community.update", %{community: community} do
      editor = TestUtils.join_with_permissions!(community, ["community.update"])

      assert {:ok, %{moderation: :full}} = Moderation.set_level(editor, community, :full)
    end

    test "logs a community's change", %{owner: owner, community: community} do
      assert {:ok, %{moderation: :full}} = Moderation.set_level(owner, community, :full)

      assert %Page{data: [%Action{action: :changed, subject_type: :community} = action]} =
               Moderation.list_log(community)

      assert action.metadata == %{"from" => "reports", "to" => "full"}
    end

    test "turns a room down", %{owner: owner, community: community} do
      room = TestUtils.get_room!(community, type: :text)

      assert {:ok, %{moderation: :none}} = Moderation.set_level(owner, room, :none)
      assert {:ok, %{moderation: nil}} = Moderation.set_level(owner, room, nil)
    end
  end

  describe "in_review/2" do
    test "leaves out unreported and decided", %{
      owner: owner,
      member: member,
      author: author,
      community: community,
      post: post
    } do
      other = TestUtils.create_random_post!(author, community)
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})
      {:ok, _kept} = Moderation.keep(owner, item)

      assert MapSet.new() == Moderation.in_review(:post, [post.id, other.id])
    end

    test "gives content with open report", %{member: member, post: post} do
      {:ok, _item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert MapSet.new([post.id]) == Moderation.in_review(:post, [post.id])
    end
  end

  describe "reported_by/3" do
    test "is empty for someone signed out", %{member: member, post: post} do
      {:ok, _item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert MapSet.new() == Moderation.reported_by(nil, :post, [post.id])
    end

    test "forgets a report once it is decided", %{owner: owner, member: member, post: post} do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})
      {:ok, _kept} = Moderation.keep(owner, item)

      assert MapSet.new() == Moderation.reported_by(member, :post, [post.id])
    end

    test "gives own reported posts", %{
      owner: owner,
      member: member,
      author: author,
      community: community,
      post: post
    } do
      other = TestUtils.create_random_post!(author, community)
      {:ok, _item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert MapSet.new([post.id]) == Moderation.reported_by(member, :post, [post.id, other.id])
      assert MapSet.new() == Moderation.reported_by(owner, :post, [post.id, other.id])
    end
  end

  describe "report/4" do
    test "fails where the level is none", %{member: member} do
      community = TestUtils.create_random_forum!(nil)
      {:ok, _membership} = Communities.join(member, community)
      post = TestUtils.create_random_post!(member, community)
      reporter = TestUtils.join_random_member!(community)

      assert {:error, :reports_off} =
               Moderation.report(reporter, :post, post.id, %{reason: :spam})
    end

    test "fails for one's own content", %{author: author, post: post} do
      assert {:error, :own} = Moderation.report(author, :post, post.id, %{reason: :spam})
    end

    test "fails for content the reporter can't read", %{owner: owner} do
      opts = [visibility: :private, moderation: :reports, template: "oss"]
      private = TestUtils.create_random_forum!(owner, opts)

      post = TestUtils.create_random_post!(owner, private)
      outsider = TestUtils.register_random_user!()

      assert {:error, :not_found} = Moderation.report(outsider, :post, post.id, %{reason: :spam})
    end

    test "fails for a reason not on the list", %{member: member, post: post} do
      assert {:error, changeset} = Moderation.report(member, :post, post.id, %{reason: :boring})
      assert %{reason: ["is invalid"]} = errors_on(changeset)
    end

    test "fails a second time from the same person", %{member: member, post: post} do
      {:ok, _item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert {:error, :already_reported} =
               Moderation.report(member, :post, post.id, %{reason: :spam})
    end

    test "queues content once", %{
      member: member,
      owner: owner,
      post: post
    } do
      post_id = post.id

      assert {:ok, %Item{source: :report, status: :pending, report_count: 1} = item} =
               Moderation.report(member, :post, post.id, %{reason: :spam, note: Lorem.sentence()})

      assert_receive %ItemQueued{subject_id: ^post_id, subject_type: :post}

      assert {:ok, %Item{report_count: 2} = again} =
               Moderation.report(owner, :post, post.id, %{reason: :harassment})

      assert again.id == item.id
      refute_receive %ItemQueued{subject_id: ^post_id}
    end

    test "queues a message in a room", %{member: member, author: author, community: community} do
      room = TestUtils.get_room!(community, type: :text)
      {:ok, message} = Chat.send_message(author, room, %{body: Lorem.sentence()})

      assert {:ok, %Item{subject_type: :message, room_id: room_id}} =
               Moderation.report(member, :message, message.id, %{reason: :spam})

      assert room_id == room.id
    end

    test "sends a direct message to the instance admins", %{member: member, author: author} do
      {:ok, conversation} = Chat.start_direct(author, member)
      {:ok, message} = Chat.send_message(author, conversation, %{body: Lorem.sentence()})

      assert {:ok, %Item{source: :instance, community_id: nil}} =
               Moderation.report(member, :message, message.id, %{reason: :harassment})
    end
  end

  describe "hold/3" do
    test "fails where the level isn't full", %{post: post} do
      assert {:error, :not_full} = Moderation.hold(:post, post.id, %{reason: Lorem.sentence()})
    end

    test "hides held reply from others", %{
      owner: owner,
      member: member,
      author: author
    } do
      community = TestUtils.create_random_forum!(owner, moderation: :full)
      {:ok, _membership} = Communities.join(author, community)
      {:ok, _membership} = Communities.join(member, community)
      post = TestUtils.create_random_post!(owner, community)
      {:ok, reply} = Forum.reply(author, post, %{body: Lorem.sentence()})

      assert {:ok, %Item{source: :automatic, score: 0.9}} =
               Moderation.hold(:reply, reply.id, %{reason: Lorem.sentence(), score: 0.9})

      assert %Page{data: []} = Forum.list_replies(post, viewer: member)
      assert %Page{data: [%{status: :pending}]} = Forum.list_replies(post, viewer: author)
      assert %Page{data: [%{status: :pending}]} = Forum.list_replies(post, viewer: owner)
    end
  end

  describe "list_queue/3" do
    test "fails without content.remove", %{member: member, community: community} do
      assert {:error, :forbidden} = Moderation.list_queue(member, community)
    end

    test "leaves out private rooms they can't see", %{
      member: member,
      author: author,
      community: community
    } do
      room = TestUtils.create_random_private_room!(community, ["member"])
      {:ok, message} = Chat.send_message(author, room, %{body: Lorem.sentence()})
      {:ok, _item} = Moderation.report(member, :message, message.id, %{reason: :spam})
      helper = TestUtils.join_with_permissions!(community, ["content.remove"])

      assert {:ok, %Page{data: []}} = Moderation.list_queue(helper, community)
      assert Moderation.queue_counts(helper) == %{}
    end

    test "lists items with content.remove", %{
      member: member,
      community: community,
      post: post
    } do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})
      helper = TestUtils.join_with_permissions!(community, ["content.remove"])

      assert {:ok, %Page{data: [%Item{} = queued]}} = Moderation.list_queue(helper, community)
      assert queued.id == item.id
      assert Moderation.subjects([item])[item.id].type == :post
      assert Moderation.queue_counts(helper) == %{community.id => 1}
    end
  end

  describe "remove/3" do
    test "fails without content.remove", %{member: member, post: post} do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert {:error, :forbidden} = Moderation.remove(member, item, Lorem.sentence())
    end

    test "fails without a reason", %{owner: owner, member: member, post: post} do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert {:error, :reason_required} = Moderation.remove(owner, item, "  ")
    end

    test "removes content and logs it", %{
      owner: owner,
      member: member,
      community: community,
      post: post
    } do
      post_id = post.id
      reason = Lorem.sentence()
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert {:ok, %Item{status: :removed}} = Moderation.remove(owner, item, reason)
      assert {:ok, %{status: :removed}} = Forum.get_post(id: post.id)
      assert_receive %ContentRemoved{subject_id: ^post_id}

      assert %Page{data: [%Action{action: :removed} = action]} = Moderation.list_log(community)
      assert action.reason == reason
      assert action.actor_id == owner.id
      assert action.target_id == post.author_id
    end
  end

  describe "keep/3" do
    test "fails once decided", %{owner: owner, member: member, post: post} do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})
      {:ok, kept} = Moderation.keep(owner, item)

      assert {:error, :invalid_transition} = Moderation.keep(owner, kept)
    end

    test "fails in a private room they can't see", %{
      member: member,
      author: author,
      community: community
    } do
      room = TestUtils.create_random_private_room!(community, ["member"])
      {:ok, message} = Chat.send_message(author, room, %{body: Lorem.sentence()})
      {:ok, item} = Moderation.report(member, :message, message.id, %{reason: :spam})
      helper = TestUtils.join_with_permissions!(community, ["content.remove"])

      assert {:error, :not_found} = Moderation.keep(helper, item)
    end

    test "keeps the content up", %{owner: owner, member: member, post: post} do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert {:ok, %Item{status: :kept}} = Moderation.keep(owner, item)
      assert {:ok, %{status: :published}} = Forum.get_post(id: post.id)
    end
  end

  describe "undo/2" do
    test "fails for an item still waiting", %{owner: owner, member: member, post: post} do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert {:error, :invalid_transition} = Moderation.undo(owner, item)
    end

    test "restores content and reopens item", %{
      owner: owner,
      member: member,
      post: post
    } do
      post_id = post.id
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})
      {:ok, removed} = Moderation.remove(owner, item, Lorem.sentence())

      assert {:ok, %Item{status: :pending}} = Moderation.undo(owner, removed)
      assert {:ok, %{status: :published}} = Forum.get_post(id: post.id)
      assert_receive %ContentRestored{subject_id: ^post_id}
    end
  end

  describe "ban_author/3" do
    test "fails without member.ban", %{member: member, community: community, post: post} do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})
      helper = TestUtils.join_with_permissions!(community, ["content.remove"])

      assert {:error, :forbidden} =
               Moderation.ban_author(helper, item, %{reason: Lorem.sentence()})
    end

    test "removes the content and bans its author", %{
      owner: owner,
      member: member,
      author: author,
      community: community,
      post: post
    } do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert {:ok, %Ban{}} = Moderation.ban_author(owner, item, %{reason: Lorem.sentence()})
      assert Communities.banned?(author, community)
      assert {:ok, %{status: :removed}} = Forum.get_post(id: post.id)
    end
  end

  describe "remove_content/4" do
    test "fails without content.remove", %{member: member, post: post} do
      assert {:error, :forbidden} =
               Moderation.remove_content(member, :post, post.id, Lorem.sentence())
    end

    test "fails in a private room they can't see", %{
      author: author,
      community: community
    } do
      room = TestUtils.create_random_private_room!(community, ["member"])
      {:ok, message} = Chat.send_message(author, room, %{body: Lorem.sentence()})
      helper = TestUtils.join_with_permissions!(community, ["content.remove"])

      assert {:error, :not_found} =
               Moderation.remove_content(helper, :message, message.id, Lorem.sentence())
    end

    test "removes and closes item", %{
      owner: owner,
      member: member,
      community: community,
      post: post
    } do
      {:ok, item} = Moderation.report(member, :post, post.id, %{reason: :spam})

      assert {:ok, %{content: %{status: :removed}}} =
               Moderation.remove_content(owner, :post, post.id, Lorem.sentence())

      assert {:ok, %Item{status: :removed}} = Moderation.get_item(item.id)
      assert {:ok, %Page{data: []}} = Moderation.list_queue(owner, community)
    end

    test "removes a reply nobody reported", %{owner: owner, author: author, post: post} do
      {:ok, reply} = Forum.reply(author, post, %{body: Lorem.sentence()})

      assert {:ok, %{content: %{status: :removed}}} =
               Moderation.remove_content(owner, :reply, reply.id, Lorem.sentence())
    end
  end

  describe "restore_content/3" do
    test "fails for content that wasn't removed", %{owner: owner, post: post} do
      assert {:error, :not_removed} = Moderation.restore_content(owner, :post, post.id)
    end

    test "puts it back and logs it", %{owner: owner, community: community, post: post} do
      {:ok, _subject} = Moderation.remove_content(owner, :post, post.id, Lorem.sentence())

      assert {:ok, %{content: %{status: :published}}} =
               Moderation.restore_content(owner, :post, post.id)

      assert %Page{data: [%Action{action: :restored} | _actions]} = Moderation.list_log(community)
    end

    test "reopens its report", %{
      owner: owner,
      member: member,
      community: community,
      post: post
    } do
      {:ok, _item} = Moderation.report(member, :post, post.id, %{reason: :spam})
      {:ok, _subject} = Moderation.remove_content(owner, :post, post.id, Lorem.sentence())

      assert {:ok, %{content: %{status: :published}}} =
               Moderation.restore_content(owner, :post, post.id)

      assert MapSet.new([post.id]) == Moderation.in_review(:post, [post.id])
      assert %Page{data: [%Action{action: :restored} | _actions]} = Moderation.list_log(community)
    end
  end

  describe "ban/4" do
    test "fails without member.ban", %{member: member, author: author, community: community} do
      assert {:error, :forbidden} =
               Moderation.ban(member, community, author, %{reason: Lorem.sentence()})
    end

    test "fails without a reason", %{owner: owner, author: author, community: community} do
      assert {:error, :reason_required} = Moderation.ban(owner, community, author, %{})
    end

    test "bans and logs it", %{owner: owner, author: author, community: community} do
      reason = Lorem.sentence()

      assert {:ok, %Ban{} = ban} = Moderation.ban(owner, community, author, %{reason: reason})
      assert ban.reason == reason

      assert {:error, :banned} = Communities.join(author, community)

      assert %Page{data: [%Action{action: :banned, subject_type: :user} = action]} =
               Moderation.list_log(community)

      assert action.target_id == author.id
    end

    test "bans again once an earlier ban ran out", %{
      owner: owner,
      author: author,
      community: community
    } do
      {:ok, ban} =
        Moderation.ban(owner, community, author, %{
          reason: Lorem.sentence(),
          expires_at: DateTime.add(DateTime.utc_now(), 1, :hour)
        })

      TestUtils.update_rows!(Ban, [id: ban.id], expires_at: TestUtils.minutes_ago(1))
      {:ok, _membership} = Communities.join(author, community)

      assert {:ok, %Ban{}} = Moderation.ban(owner, community, author, %{reason: Lorem.sentence()})
    end
  end

  describe "ban_username/4" do
    test "fails for a username nobody has", %{owner: owner, community: community} do
      assert {:error, :not_found} =
               Moderation.ban_username(owner, community, TestUtils.random_username(), %{
                 reason: Lorem.sentence()
               })
    end

    test "bans with or without at sign", %{
      owner: owner,
      author: author,
      community: community
    } do
      assert {:ok, %Ban{}} =
               Moderation.ban_username(owner, community, "@" <> author.username, %{
                 reason: Lorem.sentence()
               })

      assert Communities.banned?(author, community)
    end
  end

  describe "lift_ban/3" do
    test "fails without member.ban", %{
      owner: owner,
      member: member,
      author: author,
      community: community
    } do
      {:ok, ban} = Moderation.ban(owner, community, author, %{reason: Lorem.sentence()})

      assert {:error, :forbidden} = Moderation.lift_ban(member, ban)
    end

    test "lifts and logs it", %{owner: owner, author: author, community: community} do
      {:ok, ban} = Moderation.ban(owner, community, author, %{reason: Lorem.sentence()})

      assert {:ok, %Ban{lifted_at: %DateTime{}}} = Moderation.lift_ban(owner, ban)
      refute Communities.banned?(author, community)

      assert %Page{data: [%Action{action: :unbanned} | _actions]} = Moderation.list_log(community)
    end
  end

  describe "list_bans/2" do
    test "fails without member.ban", %{member: member, community: community} do
      assert {:error, :forbidden} = Moderation.list_bans(member, community)
    end

    test "lists the bans in force", %{owner: owner, author: author, community: community} do
      {:ok, ban} = Moderation.ban(owner, community, author, %{reason: Lorem.sentence()})
      banner = TestUtils.join_with_permissions!(community, ["member.ban"])

      assert {:ok, [%Ban{id: id}]} = Moderation.list_bans(banner, community)
      assert id == ban.id
    end
  end
end
