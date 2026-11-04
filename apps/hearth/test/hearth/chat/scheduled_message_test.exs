defmodule Hearth.Chat.ScheduledMessageTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Chat.MessageCreated
  alias Hearth.Chat.ScheduledMessageChanged
  alias Hearth.Chat.Worker.SendScheduled
  alias Hearth.Communities
  alias Hearth.TestUtils

  setup do
    :ok = Chat.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)

    [room | _rooms] = Communities.list_rooms(community)

    {:ok, binding()}
  end

  describe "schedule_message/3" do
    test "fails if not a member", %{room: room} do
      params = %{body: Lorem.sentence(), send_at: TestUtils.in_minutes(30)}

      assert {:error, :forbidden} =
               Chat.schedule_message(TestUtils.register_random_user!(), room, params)
    end

    test "fails for a time already past", %{member: member, room: room} do
      params = %{body: Lorem.sentence(), send_at: TestUtils.in_minutes(-5)}

      assert {:error, changeset} = Chat.schedule_message(member, room, params)
      assert %{send_at: ["must be at least a minute from now"]} = errors_on(changeset)
    end

    test "fails for a time more than a month out", %{member: member, room: room} do
      params = %{body: Lorem.sentence(), send_at: TestUtils.in_minutes(31 * 24 * 60)}

      assert {:error, changeset} = Chat.schedule_message(member, room, params)
      assert %{send_at: ["must be within 30 days"]} = errors_on(changeset)
    end

    test "fails for a command", %{member: member, room: room} do
      params = %{body: "/play tada", send_at: TestUtils.in_minutes(30)}

      assert {:error, changeset} = Chat.schedule_message(member, room, params)
      assert %{body: ["can't be a command"]} = errors_on(changeset)
    end

    test "waits in a room until its time", %{member: member, room: room} do
      params = %{body: Lorem.sentence(), send_at: TestUtils.in_minutes(30)}

      room_id = room.id
      assert {:ok, %{id: id}} = Chat.schedule_message(member, room, params)
      assert_enqueued(worker: SendScheduled, args: %{scheduled_id: id})
      assert_receive %ScheduledMessageChanged{scheduled_id: ^id}
      refute_receive %MessageCreated{room_id: ^room_id}
    end

    test "waits in a direct message", %{owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(member, owner)
      params = %{body: Lorem.sentence(), send_at: TestUtils.in_minutes(30)}

      assert {:ok, %{conversation_id: id}} = Chat.schedule_message(member, conversation, params)
      assert id == conversation.id
    end
  end

  describe "send_scheduled/1" do
    test "fails once the author can't post there", %{
      member: member,
      community: community,
      room: room
    } do
      scheduled = TestUtils.schedule_random_message!(member, room)
      :ok = Communities.leave(member, community)

      assert {:error, :forbidden} = Chat.send_scheduled(scheduled)
      assert {:ok, %{failure: "forbidden"}} = Chat.get_scheduled_message(member, scheduled.id)
    end

    test "sends as the author and stops waiting", %{member: member, room: room} do
      %{id: id} = scheduled = TestUtils.schedule_random_message!(member, room)

      assert {:ok, %{author_id: author_id, body: body}} = Chat.send_scheduled(scheduled)
      assert author_id == member.id
      assert body == scheduled.body
      assert {:error, :not_found} = Chat.get_scheduled_message(member, id)
    end
  end

  describe "reschedule_message/2" do
    test "fails for a time already past", %{member: member, room: room} do
      scheduled = TestUtils.schedule_random_message!(member, room)

      assert {:error, _changeset} =
               Chat.reschedule_message(scheduled, TestUtils.in_minutes(-1))
    end

    test "moves it and tries a failed one again", %{
      member: member,
      community: community,
      room: room
    } do
      scheduled = TestUtils.schedule_random_message!(member, room)
      :ok = Communities.leave(member, community)
      {:error, :forbidden} = Chat.send_scheduled(scheduled)
      {:ok, failed} = Chat.get_scheduled_message(member, scheduled.id)
      send_at = TestUtils.in_minutes(90)

      assert {:ok, %{failure: nil} = moved} = Chat.reschedule_message(failed, send_at)
      assert moved.send_at == send_at
    end
  end

  describe "cancel_scheduled_message/1" do
    test "stops it waiting", %{member: member, room: room} do
      scheduled = TestUtils.schedule_random_message!(member, room)

      assert :ok = Chat.cancel_scheduled_message(scheduled)
      assert {:error, :not_found} = Chat.get_scheduled_message(member, scheduled.id)
    end
  end

  describe "perform/1" do
    test "does nothing for a time that moved", %{member: member, room: room} do
      scheduled = TestUtils.schedule_random_message!(member, room)
      {:ok, _moved} = Chat.reschedule_message(scheduled, TestUtils.in_minutes(60))
      args = %{scheduled_id: scheduled.id, send_at: DateTime.to_iso8601(scheduled.send_at)}

      room_id = room.id
      assert :ok = perform_job(SendScheduled, args)
      refute_receive %MessageCreated{room_id: ^room_id}
    end

    test "sends the message at its time", %{member: member, room: room} do
      scheduled = TestUtils.schedule_random_message!(member, room)
      args = %{scheduled_id: scheduled.id, send_at: DateTime.to_iso8601(scheduled.send_at)}
      member_id = member.id

      assert :ok = perform_job(SendScheduled, args)
      assert_receive %MessageCreated{author_id: ^member_id}
    end
  end
end
