defmodule HearthWeb.Schema.VoiceSession do
  use JSV.Schema

  defschema %{
    title: "VoiceSession",
    type: :object,
    required: ~w[
      id
      room_id
      community_id
      host_id
      event_id
      post_id
      mode
      topic
      started_at
      ended_at
      recording
    ]a,
    properties: %{
      id: uuid(),
      room_id: uuid(),
      community_id: uuid(),
      host_id: nullable(uuid()),
      event_id: nullable(uuid()),
      post_id: nullable(uuid()),
      mode: enum(~w[stage open]),
      topic: nullable(string()),
      started_at: string(format: :"date-time"),
      ended_at: nullable(string(format: :"date-time", description: "Null while it is live")),
      recording: boolean(),
      people: integer(minimum: 0, description: "How many are in it, in the list of live sessions")
    }
  }
end
