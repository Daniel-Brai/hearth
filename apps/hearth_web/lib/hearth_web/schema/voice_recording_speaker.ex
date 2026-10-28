defmodule HearthWeb.Schema.VoiceRecordingSpeaker do
  use JSV.Schema

  defschema %{
    title: "VoiceRecordingSpeaker",
    type: :object,
    description: "AAC in an M4A",
    required: [:user_id, :url],
    properties: %{user_id: uuid(), url: string()}
  }
end
