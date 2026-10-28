defmodule HearthWeb.Schema.TranscriptSegment do
  use JSV.Schema

  defschema %{
    title: "TranscriptSegment",
    type: :object,
    required: ~w[id speaker_id start_ms end_ms text edited editable]a,
    properties: %{
      id: uuid(),
      speaker_id: uuid(),
      start_ms: non_neg_integer(description: "From the start of the recording"),
      end_ms: non_neg_integer(),
      text: string(),
      edited: boolean(),
      editable: boolean(description: "The viewer said it or may remove content")
    }
  }
end
