defmodule Hearth.Voice.Worker.EventStart do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Hearth.Events
  alias Hearth.Events.Event
  alias Hearth.Voice

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_id" => id, "starts_at" => starts_at}}) do
    {:ok, starts_at, 0} = DateTime.from_iso8601(starts_at)

    with {:ok, %Event{cancelled_at: nil} = event} <- Events.get_event(id: id),
         next = Event.next_start(event, starts_at),
         :eq <- DateTime.compare(next, starts_at) do
      ends_at = DateTime.add(starts_at, event.duration_min, :minute)
      :ok = Events.queue_voice_start(event, ends_at)

      case Voice.start_for_event(event) do
        {:ok, _session} -> :ok
        {:error, :unavailable} -> {:error, :unavailable}
        {:error, _reason} -> :ok
      end
    else
      _skipped -> :ok
    end
  end
end
