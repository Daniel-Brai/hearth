defmodule HearthWeb.Schema.Event.TranscriptReady do
  use JSV.Schema

  defschema %{
    title: "TranscriptReady",
    type: :object,
    description: "On community:<id> and the discussed post's post:<id>",
    required: ~w[transcript_id session_id recording_id community_id room_id post_id event_id]a,
    properties: %{
      transcript_id: uuid(),
      session_id: uuid(),
      recording_id: uuid(),
      community_id: uuid(),
      room_id: nullable(uuid()),
      post_id: nullable(uuid()),
      event_id: nullable(uuid())
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Transcripts.TranscriptReady
end
