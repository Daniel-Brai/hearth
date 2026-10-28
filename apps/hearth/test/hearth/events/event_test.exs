defmodule Hearth.Events.EventTest do
  use ExUnit.Case, async: true

  alias Hearth.Events.Event

  describe "next_start/2" do
    test "returns start of one off event" do
      starts_at = ~U[2026-01-05 17:00:00.000000Z]
      event = %Event{repeat: :none, starts_at: starts_at, duration_min: 60}

      assert Event.next_start(event, ~U[2027-01-01 00:00:00Z]) == starts_at
    end

    test "keeps a running occurrence" do
      event = %Event{
        repeat: :daily,
        starts_at: ~U[2026-01-05 17:00:00.000000Z],
        duration_min: 60,
        timezone: "Etc/UTC"
      }

      assert Event.next_start(event, ~U[2026-03-10 17:30:00Z]) == ~U[2026-03-10 17:00:00.000000Z]
      assert Event.next_start(event, ~U[2026-03-10 18:00:00Z]) == ~U[2026-03-11 17:00:00.000000Z]
    end

    test "keeps local time across DST" do
      # 17:00 in London is 17:00 UTC in winter and 16:00 UTC in summer
      event = %Event{
        repeat: :weekly,
        starts_at: ~U[2026-03-02 17:00:00.000000Z],
        duration_min: 60,
        timezone: "Europe/London"
      }

      next = Event.next_start(event, ~U[2026-04-01 00:00:00Z])

      assert next == ~U[2026-04-06 16:00:00.000000Z]
      assert %{hour: 17} = DateTime.shift_zone!(next, "Europe/London")
    end

    test "moves monthly by calendar month" do
      event = %Event{
        repeat: :monthly,
        starts_at: ~U[2026-01-15 09:00:00.000000Z],
        duration_min: 30,
        timezone: "Etc/UTC"
      }

      assert Event.next_start(event, ~U[2026-05-20 00:00:00Z]) == ~U[2026-06-15 09:00:00.000000Z]
    end
  end
end
