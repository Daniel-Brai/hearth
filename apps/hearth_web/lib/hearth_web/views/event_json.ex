defmodule HearthWeb.EventJSON do
  @fields ~w[
    id
    community_id
    host_id
    room_id
    title
    description
    starts_at
    next_starts_at
    duration_min
    timezone
    repeat
    place
    url
    talk_mode
    cancelled_at
  ]a

  def index(%{events: events, interested: interested}),
    do: Enum.map(events, &serialize(&1, interested))

  def show(%{event: event, interested: interested}), do: serialize(event, interested)

  def interest(%{on: on}), do: %{on: on}

  defp serialize(event, interested) do
    event
    |> Map.take(@fields)
    |> Map.put(:interested_ids, Map.get(interested, event.id, []))
  end
end
