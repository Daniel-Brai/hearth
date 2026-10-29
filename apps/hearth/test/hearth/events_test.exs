defmodule Hearth.EventsTest do
  use Hearth.DataCase, async: true

  alias Faker.Internet
  alias Faker.Lorem
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.Events.Event
  alias Hearth.Events.EventCancelled
  alias Hearth.Events.EventScheduled
  alias Hearth.Events.EventUpdated
  alias Hearth.Events.Worker.Remind
  alias Hearth.TestUtils

  setup do
    :ok = Events.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)

    voice = TestUtils.get_room!(community, type: :voice)

    params = %{
      title: Lorem.sentence(),
      starts_at: DateTime.add(DateTime.utc_now(), 2, :day),
      duration_min: 60,
      timezone: "Africa/Lagos",
      place: :room,
      room_id: voice.id
    }

    {:ok, binding()}
  end

  describe "schedule_event/3" do
    test "fails if not allowed", %{member: member, community: community, params: params} do
      assert {:error, :forbidden} = Events.schedule_event(member, community, params)
    end

    test "fails if the room is in another community", %{
      owner: owner,
      community: community,
      params: params
    } do
      [room | _rooms] =
        owner |> TestUtils.create_random_community!() |> Communities.list_rooms()

      assert {:error, :not_found} =
               Events.schedule_event(owner, community, %{params | room_id: room.id})
    end

    test "fails if it already started", %{owner: owner, community: community, params: params} do
      params = %{params | starts_at: DateTime.add(DateTime.utc_now(), -1, :hour)}

      assert {:error, changeset} = Events.schedule_event(owner, community, params)
      assert %{starts_at: ["has already passed"]} = errors_on(changeset)
    end

    test "fails if time zone or link is wrong", %{
      owner: owner,
      community: community,
      params: params
    } do
      params = Map.merge(params, %{timezone: "Mars/Olympus", place: :link, url: "ftp://x.y"})

      assert {:error, changeset} = Events.schedule_event(owner, community, params)

      assert %{timezone: ["is not a known time zone"], url: ["must be a web address"]} =
               errors_on(changeset)
    end

    test "schedule event", %{owner: owner, community: community, params: params} do
      %{id: host_id} = owner

      assert {:ok, %Event{host_id: ^host_id} = event} =
               Events.schedule_event(owner, community, params)

      assert_enqueued(worker: Remind, args: %{event_id: event.id, minutes: 60})
      assert_enqueued(worker: Remind, args: %{event_id: event.id, minutes: 10})
      assert_enqueued(worker: "Hearth.Voice.Worker.EventStart", args: %{event_id: event.id})
      assert_receive %EventScheduled{host_id: ^host_id, notify: false}
    end

    test "starts no voice session for a link", %{
      owner: owner,
      community: community,
      params: params
    } do
      params = Map.merge(params, %{place: :link, room_id: nil, url: Internet.url()})

      assert {:ok, event} = Events.schedule_event(owner, community, params)
      refute_enqueued(worker: "Hearth.Voice.Worker.EventStart", args: %{event_id: event.id})
    end

    test "asks for the members to be told", %{owner: owner, community: community, params: params} do
      assert {:ok, %Event{id: id}} = Events.schedule_event(owner, community, params, notify: true)

      assert_receive %EventScheduled{event_id: ^id, notify: true}
    end

    test "link events have no room", %{owner: owner, community: community, params: params} do
      params = Map.merge(params, %{place: :link, url: Internet.url()})

      assert {:ok, %Event{room_id: nil, talk_mode: nil}} =
               Events.schedule_event(owner, community, params)
    end
  end

  describe "update_event/3" do
    test "fails if neither host nor allowed", %{
      owner: owner,
      member: member,
      community: community,
      params: params
    } do
      {:ok, event} = Events.schedule_event(owner, community, params)

      assert {:error, :forbidden} = Events.update_event(member, event, %{title: Lorem.sentence()})
    end

    test "move event", %{owner: owner, community: community, params: params} do
      {:ok, %{id: id} = event} = Events.schedule_event(owner, community, params)
      params = %{starts_at: DateTime.add(params.starts_at, 1, :day)}

      assert {:ok, %Event{}} = Events.update_event(owner, event, params)
      assert_receive %EventUpdated{event_id: ^id, moved: true}
    end
  end

  describe "cancel_event/2" do
    test "fails if not allowed", %{
      owner: owner,
      member: member,
      community: community,
      params: params
    } do
      {:ok, event} = Events.schedule_event(owner, community, params)

      assert {:error, :forbidden} = Events.cancel_event(member, event)
    end

    test "cancel and restore event", %{owner: owner, community: community, params: params} do
      %{id: owner_id} = owner
      {:ok, event} = Events.schedule_event(owner, community, params)

      assert {:ok, %Event{cancelled_at: %DateTime{}} = cancelled} =
               Events.cancel_event(owner, event)

      assert_receive %EventCancelled{cancelled_by_id: ^owner_id}
      assert {:ok, %Event{cancelled_at: nil}} = Events.restore_event(owner, cancelled)
    end
  end

  describe "delete_event/2" do
    test "delete event", %{owner: owner, community: community, params: params} do
      {:ok, event} = Events.schedule_event(owner, community, params)

      assert {:ok, _event} = Events.delete_event(owner, event)
      assert {:error, :not_found} = Events.get_event(id: event.id)
    end
  end

  describe "toggle_interest/2" do
    test "fails if not a member", %{owner: owner, community: community, params: params} do
      {:ok, event} = Events.schedule_event(owner, community, params)

      assert {:error, :forbidden} =
               Events.toggle_interest(TestUtils.register_random_user!(), event)
    end

    test "toggle interest", %{owner: owner, member: member, community: community, params: params} do
      {:ok, event} = Events.schedule_event(owner, community, params)

      assert {:ok, :interested} = Events.toggle_interest(member, event)
      assert {:ok, :not_interested} = Events.toggle_interest(member, event)
    end
  end

  describe "list_upcoming/2" do
    test "lists soonest first with repeats moved on", %{
      owner: owner,
      community: community,
      params: params
    } do
      {:ok, _later} = Events.schedule_event(owner, community, params)
      sooner = %{params | starts_at: DateTime.add(DateTime.utc_now(), 1, :hour)}
      {:ok, %{id: sooner_id}} = Events.schedule_event(owner, community, sooner)

      assert [%Event{id: ^sooner_id, next_starts_at: %DateTime{}} | _later] =
               Events.list_upcoming([community.id])
    end
  end

  describe "create_template_event/2" do
    test "returns nothing for a template without one", %{community: community} do
      assert {:ok, nil} = Events.create_template_event(community.id, "blank")
    end

    test "create template event", %{owner: owner, community: community} do
      %{id: owner_id} = owner

      assert {:ok, %Event{title: "Office hours", repeat: :weekly, host_id: ^owner_id} = event} =
               Events.create_template_event(community.id, "oss")

      assert %{hour: 17} = DateTime.shift_zone!(event.starts_at, event.timezone)
    end
  end
end
