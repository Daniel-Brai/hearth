defmodule HearthWeb.Schema.CommunityEvent do
  use JSV.Schema

  defschema %{
    title: "CommunityEvent",
    type: :object,
    required: ~w[
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
      interested_ids
    ]a,
    properties: %{
      id: uuid(),
      community_id: uuid(),
      host_id: uuid(),
      room_id: nullable(uuid()),
      title: string(),
      description: nullable(string()),
      starts_at: string(format: :"date-time", description: "The first occurrence"),
      next_starts_at:
        nullable(string(format: :"date-time", description: "For a repeating event")),
      duration_min: integer(),
      timezone: string(),
      repeat: enum(~w[none daily weekly biweekly monthly]),
      place: enum(~w[room link]),
      url: nullable(string()),
      talk_mode: nullable(enum(~w[stage open])),
      cancelled_at: nullable(string(format: :"date-time")),
      interested_ids: array_of(uuid(), description: "The host first")
    }
  }
end
