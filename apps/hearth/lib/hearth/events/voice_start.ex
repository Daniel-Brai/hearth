defmodule Hearth.Events.VoiceStart do
  # Voice depends on Events so this job names its worker as a string instead of calling it

  alias Hearth.Events.Event
  alias Oban.Job

  @worker "Hearth.Voice.Worker.EventStart"

  @spec schedule(Event.t(), DateTime.t()) :: :ok
  def schedule(event, from \\ DateTime.utc_now())

  def schedule(%Event{place: :room, talk_mode: mode, cancelled_at: nil} = event, from)
      when mode != nil do
    starts_at = Event.next_start(event, from)

    %{event_id: event.id, starts_at: DateTime.to_iso8601(starts_at)}
    |> Job.new(
      worker: @worker,
      queue: :default,
      max_attempts: 3,
      scheduled_at: starts_at,
      unique: [period: :infinity, keys: [:event_id, :starts_at], states: :incomplete]
    )
    |> Oban.insert!()

    :ok
  end

  def schedule(%Event{}, _from), do: :ok
end
