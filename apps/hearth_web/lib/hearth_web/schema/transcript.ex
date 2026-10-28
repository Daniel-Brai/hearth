defmodule HearthWeb.Schema.Transcript do
  use JSV.Schema

  alias HearthWeb.Schema.TranscriptSegment
  alias HearthWeb.Schema.TranscriptSpeaker
  alias HearthWeb.Schema.UserSummary
  alias HearthWeb.Schema.VoiceRecording

  defschema %{
    title: "Transcript",
    type: :object,
    description: "Lines are empty until it is ready",
    required: ~w[
      id
      session_id
      recording_id
      community_id
      room_id
      room_name
      post_id
      topic
      status
      failure
      language
      duration_ms
      started_at
      ready_at
      speakers
      segments
      silences
      people
      recording
    ]a,
    properties: %{
      id: uuid(),
      session_id: uuid(),
      recording_id: uuid(),
      community_id: uuid(),
      room_id: uuid(),
      room_name: string(),
      post_id: nullable(uuid()),
      topic: nullable(string()),
      status: enum(~w[queued transcribing ready failed]),
      failure: nullable(string()),
      language: nullable(string()),
      duration_ms: nullable(integer()),
      started_at: string(format: :"date-time"),
      ready_at: nullable(string(format: :"date-time")),
      speakers: array_of(TranscriptSpeaker),
      segments: array_of(TranscriptSegment),
      silences:
        array_of(%{
          type: :object,
          description: "Stretches over two seconds where nobody spoke, for skipping",
          required: [:start_ms, :end_ms],
          properties: %{start_ms: non_neg_integer(), end_ms: non_neg_integer()}
        }),
      people: array_of(UserSummary),
      recording: VoiceRecording
    }
  }
end
