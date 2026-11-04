defmodule HearthWeb.Schema.ScheduleEventBody do
  use JSV.Schema

  alias Hearth.Events.Event
  alias HearthWeb.Schema

  defschema %{
    title: "ScheduleEventBody",
    type: :object,
    required: ~w[title starts_at duration_min timezone place]a,
    additionalProperties: false,
    properties: %{
      notify: boolean(),
      title: string(minLength: 1, maxLength: 120),
      description: nullable(string(maxLength: 4_000)),
      starts_at: string(format: :"date-time", description: "Must be ahead"),
      duration_min: integer(minimum: 5, maximum: 720),
      timezone:
        string(
          maxLength: 64,
          description: "IANA zone such as Africa/Lagos"
        ),
      repeat: Schema.enum_of(Event, :repeat),
      place: Schema.enum_of(Event, :place),
      room_id: nullable(uuid()),
      url: nullable(string(maxLength: 2_000)),
      talk_mode: nullable(Schema.enum_of(Event, :talk_mode))
    }
  }
end
