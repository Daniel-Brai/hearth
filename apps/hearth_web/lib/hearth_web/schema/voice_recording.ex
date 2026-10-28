defmodule HearthWeb.Schema.VoiceRecording do
  use JSV.Schema

  alias HearthWeb.Schema.VoiceRecordingSpeaker

  defschema %{
    title: "VoiceRecording",
    type: :object,
    description: "The addresses are signed, last a few hours and are null until it is ready",
    required: ~w[
      id
      session_id
      room_id
      community_id
      started_by_id
      title
      status
      failure
      started_at
      ended_at
      duration_ms
      byte_size
      width
      height
      has_screen
      video_url
      download_url
      poster_url
      speakers
    ]a,
    properties: %{
      id: uuid(),
      session_id: uuid(),
      room_id: uuid(),
      community_id: uuid(),
      started_by_id: nullable(uuid()),
      title:
        nullable(
          string(description: "The event's title or the session's topic, null for a plain room")
        ),
      status:
        enum(~w[recording processing ready failed],
          description:
            "Recording while the session goes on, then processing until the video is made"
        ),
      failure: nullable(string()),
      started_at: string(format: :"date-time"),
      ended_at: nullable(string(format: :"date-time")),
      duration_ms: nullable(integer()),
      byte_size: nullable(integer()),
      width: nullable(integer()),
      height: nullable(integer()),
      has_screen: boolean(),
      video_url: nullable(string()),
      download_url: nullable(string()),
      poster_url: nullable(string()),
      speakers: array_of(VoiceRecordingSpeaker)
    }
  }
end
