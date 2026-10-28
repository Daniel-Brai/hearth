defmodule Hearth.Chat.ScreeningTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Communities
  alias Hearth.Communities.Room
  alias Hearth.Moderation.Worker.Screen
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner, moderation: :full)
    author = TestUtils.join_random_member!(community)
    [room | _rooms] = Communities.list_rooms(community)

    {:ok, binding()}
  end

  describe "send_message/3" do
    test "queues no screening in a room set below full", %{author: author, room: room} do
      :ok = TestUtils.update_rows!(Room, [id: room.id], moderation: :reports)
      {:ok, room} = Communities.get_room(id: room.id)

      {:ok, message} = Chat.send_message(author, room, %{body: Lorem.sentence()})

      refute_enqueued(worker: Screen, args: %{subject_id: message.id})
    end

    test "skips direct message without image floor", %{
      owner: owner,
      author: author
    } do
      {:ok, conversation} = Chat.start_direct(author, owner)

      {:ok, message} = Chat.send_message(author, conversation, %{body: Lorem.sentence()})

      refute_enqueued(worker: Screen, args: %{subject_id: message.id})
    end

    test "queues room message at full", %{author: author, room: room} do
      {:ok, message} = Chat.send_message(author, room, %{body: Lorem.sentence()})

      assert_enqueued(worker: Screen, args: %{subject_type: "message", subject_id: message.id})
    end
  end

  describe "edit_message/3" do
    test "screens the message again after an edit", %{author: author, room: room} do
      :ok = TestUtils.update_rows!(Room, [id: room.id], moderation: :reports)
      {:ok, room} = Communities.get_room(id: room.id)
      {:ok, message} = Chat.send_message(author, room, %{body: Lorem.sentence()})
      :ok = TestUtils.update_rows!(Room, [id: room.id], moderation: nil)

      assert {:ok, _message} = Chat.edit_message(author, message, %{body: Lorem.sentence()})
      assert_enqueued(worker: Screen, args: %{subject_type: "message", subject_id: message.id})
    end
  end
end
