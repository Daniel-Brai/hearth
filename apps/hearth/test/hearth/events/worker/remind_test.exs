defmodule Hearth.Events.Worker.RemindTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Events
  alias Hearth.Events.EventReminder
  alias Hearth.Events.Worker.Remind
  alias Hearth.TestUtils

  setup do
    :ok = Events.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")

    voice = TestUtils.get_room!(community, type: :voice)

    params = %{
      title: Lorem.sentence(),
      starts_at: DateTime.add(DateTime.utc_now(), 2, :day),
      duration_min: 60,
      place: :room,
      room_id: voice.id,
      repeat: :weekly
    }

    {:ok, event} = Events.schedule_event(owner, community, params)
    starts_at = DateTime.to_iso8601(event.starts_at)

    {:ok, binding()}
  end

  describe "perform/1" do
    test "skips a cancelled event", %{owner: owner, event: event, starts_at: starts_at} do
      {:ok, _event} = Events.cancel_event(owner, event)

      event_id = event.id

      assert :ok = perform_job(Remind, %{event_id: event_id, starts_at: starts_at, minutes: 10})
      refute_receive %EventReminder{event_id: ^event_id}
    end

    test "skips an occurrence that moved", %{owner: owner, event: event, starts_at: starts_at} do
      {:ok, _event} =
        Events.update_event(owner, event, %{starts_at: DateTime.add(event.starts_at, 1, :hour)})

      event_id = event.id

      assert :ok = perform_job(Remind, %{event_id: event_id, starts_at: starts_at, minutes: 10})
      refute_receive %EventReminder{event_id: ^event_id}
    end

    test "remind and queue the next occurrence", %{
      owner: owner,
      event: event,
      starts_at: starts_at
    } do
      %{id: owner_id} = owner

      assert :ok = perform_job(Remind, %{event_id: event.id, starts_at: starts_at, minutes: 10})
      assert_receive %EventReminder{minutes: 10, user_ids: [^owner_id]}

      next = event.starts_at |> DateTime.add(7, :day) |> DateTime.to_iso8601()
      assert_enqueued(worker: Remind, args: %{event_id: event.id, starts_at: next, minutes: 60})
    end
  end
end
