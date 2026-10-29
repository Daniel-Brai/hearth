defmodule Hearth.Notifications.Listener.ModerationTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Moderation
  alias Hearth.Moderation.ItemQueued
  alias Hearth.Notifications
  alias Hearth.Notifications.Listener.Moderation, as: Listener
  alias Hearth.Notifications.Notification
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner, moderation: :reports)
    author = TestUtils.join_random_member!(community)
    reporter = TestUtils.join_random_member!(community)
    :ok = Moderation.subscribe_to_pubsub()

    {:ok, binding()}
  end

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
  end

  test "tells moderators but not reporter", %{
    owner: owner,
    community: community,
    author: author,
    reporter: reporter
  } do
    helper = TestUtils.join_with_permissions!(community, ["content.remove"])
    bystander = TestUtils.join_random_member!(community)
    %{id: post_id} = TestUtils.create_random_post!(author, community)
    {:ok, _item} = Moderation.report(reporter, :post, post_id, %{reason: :spam})
    assert_receive %ItemQueued{subject_id: ^post_id} = event

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :report, actor_id: nil}]} =
             Notifications.list_notifications(owner)

    assert %Page{data: [%Notification{kind: :report, actor_id: nil}]} =
             Notifications.list_notifications(helper)

    assert %Page{data: []} = Notifications.list_notifications(reporter)
    assert %Page{data: []} = Notifications.list_notifications(author)
    assert %Page{data: []} = Notifications.list_notifications(bystander)
  end

  test "tells admins about direct message", %{author: author, reporter: reporter} do
    admin = TestUtils.register_random_user!(admin: true)
    {:ok, conversation} = Chat.start_direct(author, reporter)
    {:ok, %{id: message_id}} = Chat.send_message(author, conversation, %{body: Lorem.sentence()})
    {:ok, _item} = Moderation.report(reporter, :message, message_id, %{reason: :harassment})
    assert_receive %ItemQueued{community_id: nil, subject_id: ^message_id} = event

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert %Page{data: [%Notification{kind: :report}]} = Notifications.list_notifications(admin)
  end
end
