defmodule HearthWeb.Schema.UpdateEventBody do
  use JSV.Schema

  defschema %{
    title: "UpdateEventBody",
    type: :object,
    description: "Only the fields sent change",
    additionalProperties: false,
    properties: %{
      title: string(minLength: 1, maxLength: 120),
      description: nullable(string(maxLength: 4_000)),
      starts_at: string(format: :"date-time", description: "Must be ahead"),
      duration_min: integer(minimum: 5, maximum: 720),
      timezone:
        string(
          maxLength: 64,
          description: "IANA zone such as Africa/Lagos"
        ),
      repeat: enum(~w[none daily weekly biweekly monthly]),
      place: enum(~w[room link]),
      room_id: nullable(uuid()),
      url: nullable(string(maxLength: 2_000)),
      talk_mode: nullable(enum(~w[stage open]))
    }
  }
end
