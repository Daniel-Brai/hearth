defmodule Hearth.Chat.PinTest do
  use Hearth.DataCase, async: true

  alias Hearth.Chat
  alias Hearth.Chat.Message
  alias Hearth.Chat.MessageCreated
  alias Hearth.Chat.MessagePinsChanged
  alias Hearth.Communities
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    member = TestUtils.join_random_member!(community)

    [room | _rooms] = Communities.list_rooms(community)
    message = TestUtils.send_random_message!(member, room)

    {:ok, binding()}
  end

  describe "pin_message/2" do
    test "fails without message.pin", %{member: member, message: message} do
      assert {:error, :forbidden} = Chat.pin_message(member, message)
    end

    test "fails for a sound", %{owner: owner, room: room} do
      [sound | _sounds] = Message.sounds()
      played = TestUtils.send_random_message!(owner, room, kind: :sound, body: sound)

      assert {:error, :not_pinnable} = Chat.pin_message(owner, played)
    end

    test "tells open apps", %{owner: owner, room: room, message: message} do
      :ok = Chat.subscribe_to_pubsub()
      room_id = room.id

      :ok = Chat.pin_message(owner, message)

      assert_receive %MessagePinsChanged{room_id: ^room_id}
    end

    test "posts a notice once", %{owner: owner, room: room, message: message} do
      :ok = Chat.pin_message(owner, message)
      :ok = Chat.subscribe_to_pubsub()
      room_id = room.id

      :ok = Chat.pin_message(owner, message)

      refute_receive %MessageCreated{room_id: ^room_id}
    end

    test "drops the oldest past three", %{owner: owner, member: member, room: room} = context do
      :ok = Chat.pin_message(owner, context.message)
      newer = TestUtils.send_random_messages!(member, room, 3)
      :ok = TestUtils.pin_messages!(owner, newer)

      assert {:ok, pins} = Chat.list_pins(owner, room)
      refute context.message.id in TestUtils.pluck(pins, :id)
    end
  end

  describe "unpin_message/2" do
    test "fails without message.pin", %{owner: owner, member: member, message: message} do
      :ok = Chat.pin_message(owner, message)

      assert {:error, :forbidden} = Chat.unpin_message(member, message)
    end

    test "takes the pin away", %{owner: owner, room: room, message: message} do
      :ok = Chat.pin_message(owner, message)
      :ok = Chat.unpin_message(owner, message)

      assert {:ok, []} = Chat.list_pins(owner, room)
    end
  end

  describe "list_pins/2" do
    test "fails for a room you can't see", %{member: member, community: community} do
      private = TestUtils.create_random_private_room!(community, ["moderator"])

      assert {:error, :not_found} = Chat.list_pins(member, private)
    end

    test "lists the newest pin first", %{owner: owner, member: member, room: room} = context do
      newer = TestUtils.send_random_message!(member, room)
      :ok = TestUtils.pin_messages!(owner, [context.message, newer])

      assert {:ok, [%{id: id} | _rest]} = Chat.list_pins(member, room)
      assert id == newer.id
    end
  end

  describe "delete_message/2" do
    test "takes its pin away", %{owner: owner, member: member, room: room, message: message} do
      :ok = Chat.pin_message(owner, message)
      {:ok, _message} = Chat.delete_message(member, message)

      assert {:ok, []} = Chat.list_pins(owner, room)
    end
  end
end
