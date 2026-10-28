defmodule HearthWeb.Schema.VoiceRecordingNow do
  use JSV.Schema

  defschema %{
    title: "VoiceRecordingNow",
    type: :object,
    required: [:id, :started_by_id, :started_at],
    properties: %{
      id: uuid(),
      started_by_id: nullable(uuid()),
      started_at: string(format: :"date-time")
    }
  }
end
