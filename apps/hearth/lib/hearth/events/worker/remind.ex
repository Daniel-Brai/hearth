defmodule Hearth.Events.Worker.Remind do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:event_id, :starts_at, :minutes], states: :incomplete]

  alias Hearth.Events
  alias Hearth.Events.Event
  alias Hearth.Events.EventReminder
  alias Hearth.Events.Interest

  @before [60, 10]

  @spec schedule(Event.t(), DateTime.t()) :: :ok
  def schedule(%Event{} = event, from \\ DateTime.utc_now()) do
    starts_at = Event.next_start(event, from)

    for minutes <- @before,
        at = DateTime.add(starts_at, -minutes, :minute),
        DateTime.after?(at, DateTime.utc_now()) do
      %{event_id: event.id, starts_at: DateTime.to_iso8601(starts_at), minutes: minutes}
      |> new(scheduled_at: at)
      |> Oban.insert!()
    end

    :ok
  end

  # The event is loaded again so a reminder for a moved or cancelled occurrence does nothing
  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"event_id" => id, "starts_at" => starts_at, "minutes" => minutes}
      }) do
    {:ok, starts_at, 0} = DateTime.from_iso8601(starts_at)

    with %Event{cancelled_at: nil} = event <- Event.get(id: id),
         next = Event.next_start(event, DateTime.utc_now()),
         :eq <- DateTime.compare(next, starts_at) do
      remind(event, starts_at, minutes)
    else
      _skipped -> :ok
    end
  end

  defp remind(event, starts_at, minutes) do
    Events.broadcast_to_pubsub(%EventReminder{
      event_id: event.id,
      community_id: event.community_id,
      starts_at: starts_at,
      minutes: minutes,
      user_ids: Interest.user_ids(event.id)
    })

    :ok = Interest.mark_reminded(event.id)

    # The last reminder of a repeating event queues the next occurrence's
    if minutes == List.last(@before) and event.repeat != :none do
      schedule(event, DateTime.add(starts_at, event.duration_min, :minute))
    end

    :ok
  end
end
