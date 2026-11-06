defmodule Hearth.Chat.PollTest do
  use Hearth.DataCase, async: true

  alias Hearth.Chat
  alias Hearth.Chat.MessageCreated
  alias Hearth.Chat.PollUpdated
  alias Hearth.Chat.Worker.ClosePoll
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.TestUtils

  setup do
    :ok = Chat.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    member = TestUtils.join_random_member!(community)

    [room | _rooms] = Communities.list_rooms(community)

    {:ok, binding()}
  end

  describe "start_poll/3" do
    test "fails if not a member", %{room: room} do
      outsider = TestUtils.register_random_user!()

      assert {:error, :forbidden} =
               Chat.start_poll(outsider, room, TestUtils.random_poll_params())
    end

    test "fails in a direct message", %{owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(member, owner)

      assert {:error, :forbidden} =
               Chat.start_poll(member, conversation, TestUtils.random_poll_params())
    end

    test "fails with one choice", %{member: member, room: room} do
      params = TestUtils.random_poll_params(choices: 1)

      assert {:error, changeset} = Chat.start_poll(member, room, params)
      assert %{options: ["must have 2 to 10 choices"]} = errors_on(changeset)
    end

    test "fails with the same choice twice", %{member: member, room: room} do
      params = %{TestUtils.random_poll_params() | options: ~w[Tea tea]}

      assert {:error, changeset} = Chat.start_poll(member, room, params)
      assert %{options: ["must all be different"]} = errors_on(changeset)
    end

    test "fails closing in the past", %{member: member, room: room} do
      params = TestUtils.random_poll_params(closes_at: TestUtils.in_minutes(-5))

      assert {:error, changeset} = Chat.start_poll(member, room, params)
      assert %{closes_at: ["must be at least 1 minute from now"]} = errors_on(changeset)
    end

    test "asks in the room", %{member: member, room: room} do
      room_id = room.id

      assert {:ok, %{kind: :poll}} =
               Chat.start_poll(member, room, TestUtils.random_poll_params())

      assert_receive %MessageCreated{room_id: ^room_id}
    end

    test "closes later by itself", %{member: member, room: room} do
      poll = TestUtils.start_random_poll!(member, room, closes_at: TestUtils.in_minutes(10))

      assert_enqueued(worker: ClosePoll, args: %{poll_id: poll.id})
    end
  end

  describe "vote/3" do
    test "fails if not a member", %{owner: owner, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      [option | _options] = poll.options

      assert {:error, :forbidden} =
               Chat.vote(TestUtils.register_random_user!(), poll, [option.id])
    end

    test "fails once closed", %{owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      {:ok, closed} = Chat.close_poll(owner, poll)
      [option | _options] = poll.options

      assert {:error, :poll_closed} = Chat.vote(member, closed, [option.id])
    end

    test "fails for two picks in a single choice poll", %{
      owner: owner,
      member: member,
      room: room
    } do
      poll = TestUtils.start_random_poll!(owner, room)
      [first, second | _options] = poll.options

      assert {:error, :invalid_choice} = Chat.vote(member, poll, [first.id, second.id])
    end

    test "fails for a choice from another poll", %{owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)

      assert {:error, :invalid_choice} = Chat.vote(member, poll, [Common.new_id()])
    end

    test "counts a vote", %{owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      [option | _options] = poll.options

      assert {:ok, %{voters: 1, mine: [picked]}} = Chat.vote(member, poll, [option.id])
      assert picked == option.id
    end

    test "replaces an earlier vote", %{owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      [first, second | _options] = poll.options
      {:ok, _view} = Chat.vote(member, poll, [first.id])

      assert {:ok, %{counts: counts}} = Chat.vote(member, poll, [second.id])
      assert counts == %{second.id => 1}
    end

    test "takes several picks when allowed", %{owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room, multiple: true)
      [first, second | _options] = poll.options

      assert {:ok, %{voters: 1, mine: mine}} = Chat.vote(member, poll, [first.id, second.id])
      assert Enum.sort(mine) == Enum.sort([first.id, second.id])
    end

    test "tells the room the totals", %{owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      [option | _options] = poll.options
      poll_id = poll.id

      {:ok, _view} = Chat.vote(member, poll, [option.id])

      assert_receive %PollUpdated{poll_id: ^poll_id, voters: 1}
    end
  end

  describe "close_poll/2" do
    test "fails for someone else's poll", %{owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)

      assert {:error, :forbidden} = Chat.close_poll(member, poll)
    end

    test "fails once closed", %{owner: owner, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      {:ok, closed} = Chat.close_poll(owner, poll)

      assert {:error, :poll_closed} = Chat.close_poll(owner, closed)
    end

    test "closes its own poll", %{member: member, room: room} do
      poll = TestUtils.start_random_poll!(member, room)

      assert {:ok, %{closed_at: %DateTime{}}} = Chat.close_poll(member, poll)
    end

    test "closes anyone's poll as a moderator", %{owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(member, room)

      assert {:ok, %{closed_at: %DateTime{}}} = Chat.close_poll(owner, poll)
    end
  end

  describe "edit_message/3" do
    test "fails for a poll", %{member: member, room: room} do
      {:ok, message} = Chat.start_poll(member, room, TestUtils.random_poll_params())

      assert {:error, :forbidden} = Chat.edit_message(member, message, %{body: "Changed"})
    end
  end

  describe "perform/1" do
    test "does nothing for a closed poll", %{owner: owner, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      poll_id = poll.id
      {:ok, _closed} = Chat.close_poll(owner, poll)
      assert_receive %PollUpdated{poll_id: ^poll_id}

      assert :ok = perform_job(ClosePoll, %{poll_id: poll.id})
      refute_receive %PollUpdated{poll_id: ^poll_id}
    end

    test "closes the poll at its time", %{owner: owner, room: room} do
      poll = TestUtils.start_random_poll!(owner, room, closes_at: TestUtils.in_minutes(10))
      poll_id = poll.id

      assert :ok = perform_job(ClosePoll, %{poll_id: poll.id})
      assert_receive %PollUpdated{poll_id: ^poll_id, closed_at: %DateTime{}}
    end
  end
end
