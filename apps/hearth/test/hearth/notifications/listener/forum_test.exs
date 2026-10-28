defmodule Hearth.Notifications.Listener.ForumTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Forum.AnswerMarked
  alias Hearth.Forum.PostCreated
  alias Hearth.Forum.ReplyCreated
  alias Hearth.Notifications
  alias Hearth.Notifications.Listener.Forum, as: Listener
  alias Hearth.Notifications.Notification
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)
    post = TestUtils.create_random_post!(owner, community)

    {:ok, binding()}
  end

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
  end

  test "tells nobody about replying to one's own post", %{
    owner: owner,
    community: community,
    post: post
  } do
    {:ok, reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

    event = %ReplyCreated{
      reply_id: reply.id,
      post_id: post.id,
      parent_reply_id: nil,
      community_id: community.id,
      author_id: owner.id,
      parent_author_id: nil,
      post_author_id: owner.id
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert %Page{data: []} = Notifications.list_notifications(owner)
  end

  test "tells nobody who turned replies off", %{owner: owner, member: member, post: post} do
    {:ok, _settings} =
      Accounts.update_settings(owner, %{notification_prefs: %{"replies" => false}})

    {:ok, reply} = Forum.reply(member, post, %{body: Lorem.sentence()})
    event = TestUtils.reply_created(reply, post, member)

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert %Page{data: []} = Notifications.list_notifications(owner)
  end

  test "tells nobody who turned mentions off", %{
    owner: owner,
    member: member,
    community: community
  } do
    {:ok, _settings} =
      Accounts.update_settings(member, %{notification_prefs: %{"mentions" => false}})

    post = TestUtils.create_random_post!(owner, community, body: "Ask @#{member.username}")
    event = %PostCreated{post_id: post.id, community_id: community.id, author_id: owner.id}

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert %Page{data: []} = Notifications.list_notifications(member)
  end

  test "tells nobody who stopped watching", %{
    owner: owner,
    member: member,
    community: community,
    post: post
  } do
    watcher = TestUtils.join_random_member!(community)
    :ok = Forum.watch_post(watcher, post, false)
    {:ok, reply} = Forum.reply(member, post, %{body: Lorem.sentence()})
    event = TestUtils.reply_created(reply, post, member)

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert %Page{data: []} = Notifications.list_notifications(watcher)
    assert %Page{data: [%Notification{kind: :reply}]} = Notifications.list_notifications(owner)
  end

  test "tells everyone watching the post once", %{
    owner: owner,
    member: member,
    community: community,
    post: post
  } do
    watcher = TestUtils.join_random_member!(community)
    :ok = Forum.watch_post(watcher, post, true)
    {:ok, reply} = Forum.reply(member, post, %{body: Lorem.sentence()})
    event = TestUtils.reply_created(reply, post, member)

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :reply, actor_id: actor_id}]} =
             Notifications.list_notifications(watcher)

    assert actor_id == member.id
    assert %Page{data: [%Notification{kind: :reply}]} = Notifications.list_notifications(owner)
    assert %Page{data: []} = Notifications.list_notifications(member)
  end

  test "tells mentioned watcher only", %{member: member, community: community, post: post} do
    watcher = TestUtils.join_random_member!(community)
    :ok = Forum.watch_post(watcher, post, true)
    {:ok, reply} = Forum.reply(member, post, %{body: "Thoughts @#{watcher.username}?"})
    event = TestUtils.reply_created(reply, post, member)

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :mention}]} =
             Notifications.list_notifications(watcher)
  end

  test "tells the post's author about a reply", %{
    owner: owner,
    member: member,
    community: community,
    post: post
  } do
    {:ok, reply} = Forum.reply(member, post, %{body: Lorem.sentence()})

    event = %ReplyCreated{
      reply_id: reply.id,
      post_id: post.id,
      parent_reply_id: nil,
      community_id: community.id,
      author_id: member.id,
      parent_author_id: nil,
      post_author_id: owner.id
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :reply, actor_id: actor_id, data: data}]} =
             Notifications.list_notifications(owner)

    assert actor_id == member.id
    assert data["post_title"] == post.title
  end

  test "tells the people a post mentions", %{owner: owner, member: member, community: community} do
    post =
      TestUtils.create_random_post!(owner, community,
        body: "Ask @#{member.username} or @nobody_here"
      )

    event = %PostCreated{post_id: post.id, community_id: community.id, author_id: owner.id}

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :mention}]} = Notifications.list_notifications(member)
  end

  test "tells author of accepted answer", %{
    owner: owner,
    member: member,
    post: post
  } do
    {:ok, reply} = Forum.reply(member, post, %{body: Lorem.sentence()})
    event = %AnswerMarked{post_id: post.id, reply_id: reply.id, reply_author_id: member.id}

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :answer, actor_id: actor_id}]} =
             Notifications.list_notifications(member)

    assert actor_id == owner.id
  end
end
