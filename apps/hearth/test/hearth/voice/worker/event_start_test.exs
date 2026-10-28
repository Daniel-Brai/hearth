defmodule Hearth.Voice.Worker.EventStartTest do
  use Hearth.DataCase, async: false

  alias Hearth.Events
  alias Hearth.TestUtils
  alias Hearth.Voice
  alias Hearth.Voice.Session
  alias Hearth.Voice.Worker.EventStart

  setup do
    :ok = TestUtils.start_voice!()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    event = TestUtils.create_random_community_event!(owner, community, repeat: :weekly)
    starts_at = DateTime.to_iso8601(event.starts_at)

    {:ok, binding()}
  end

  describe "perform/1" do
    test "skips a cancelled event", %{owner: owner, event: event, starts_at: starts_at} do
      {:ok, _event} = Events.cancel_event(owner, event)

      assert :ok = perform_job(EventStart, %{event_id: event.id, starts_at: starts_at})
      assert {:error, :not_found} = Voice.get_session(room_id: event.room_id)
    end

    test "skips a moved event", %{owner: owner, event: event, starts_at: starts_at} do
      {:ok, _event} =
        Events.update_event(owner, event, %{starts_at: DateTime.add(event.starts_at, 1, :hour)})

      assert :ok = perform_job(EventStart, %{event_id: event.id, starts_at: starts_at})
      assert {:error, :not_found} = Voice.get_session(room_id: event.room_id)
    end

    test "starts the event's session", %{owner: owner, event: event, starts_at: starts_at} do
      %{id: event_id, room_id: room_id} = event
      %{id: host_id} = owner
      next = event.starts_at |> DateTime.add(7, :day) |> DateTime.to_iso8601()

      assert :ok = perform_job(EventStart, %{event_id: event_id, starts_at: starts_at})

      assert {:ok, %Session{event_id: ^event_id, host_id: ^host_id, mode: :open}} =
               Voice.get_session(room_id: room_id, ended_at: nil)

      assert_enqueued(worker: EventStart, args: %{event_id: event_id, starts_at: next})
    end
  end
end
