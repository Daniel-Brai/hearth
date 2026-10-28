defmodule HearthWeb.Schema.VoiceRecordingList do
  use JSV.Schema

  alias HearthWeb.Schema.VoiceRecording

  defschema %{
    title: "VoiceRecordingList",
    type: :object,
    required: [:data],
    properties: %{
      data:
        array_of(VoiceRecording,
          description: "Newest first, at most 50, failed ones only for people who may record"
        )
    }
  }
end
