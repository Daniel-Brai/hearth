defmodule Hearth.Notifications.Listener.ChatTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Chat.MessageCreated
  alias Hearth.Communities
  alias Hearth.Notifications
  alias Hearth.Notifications.Listener.Chat, as: Listener
  alias Hearth.Notifications.Notification
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)

    {:ok, binding()}
  end

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
  end

  test "tells others about direct message", %{
    owner: owner,
    member: member
  } do
    {:ok, conversation} = Chat.start_direct(member, owner)
    {:ok, message} = Chat.send_message(member, conversation, %{body: Lorem.sentence()})

    event = %MessageCreated{
      message_id: message.id,
      room_id: nil,
      conversation_id: conversation.id,
      author_id: member.id,
      reply_to_author_id: nil
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :dm}]} = Notifications.list_notifications(owner)
    assert %Page{data: []} = Notifications.list_notifications(member)
  end

  test "tells nobody about a promoted note", %{owner: owner, member: member} do
    community = TestUtils.create_random_forum!(owner)
    {:ok, _membership} = Communities.join(member, community)
    room = TestUtils.get_room!(community, type: :text)

    post = %{
      id: TestUtils.create_random_post!(owner, community).id,
      title: "Ask @#{member.username}"
    }

    {:ok, notice} = Chat.note_promoted(owner, room, post)

    event = %MessageCreated{
      message_id: notice.id,
      room_id: room.id,
      conversation_id: nil,
      author_id: owner.id,
      reply_to_author_id: nil
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert %Page{data: []} = Notifications.list_notifications(member)
  end

  test "tells the people a room message mentions", %{
    owner: owner,
    member: member,
    community: community
  } do
    room = TestUtils.get_room!(community, type: :text)
    {:ok, message} = Chat.send_message(owner, room, %{body: "Welcome @#{member.username}"})

    event = %MessageCreated{
      message_id: message.id,
      room_id: room.id,
      conversation_id: nil,
      author_id: owner.id,
      reply_to_author_id: nil
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :mention, data: data}]} =
             Notifications.list_notifications(member)

    assert data["room_slug"] == room.slug
  end

  test "links voice chat mention to the room", %{
    owner: owner,
    member: member,
    community: community
  } do
    room = TestUtils.create_random_voice_room!(community)
    {:ok, message} = Chat.send_message(owner, room, %{body: "Over here @#{member.username}"})

    event = %MessageCreated{
      message_id: message.id,
      room_id: room.id,
      conversation_id: nil,
      author_id: owner.id,
      reply_to_author_id: nil
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert %Page{data: [%Notification{kind: :mention, data: %{"url" => url}}]} =
             Notifications.list_notifications(member)

    assert url == "/c/#{community.slug}/voice/#{room.slug}"
  end
end
