defmodule HearthWeb.Schema.VoiceRecordingPage do
  use JSV.Schema

  alias HearthWeb.Schema.PageMeta
  alias HearthWeb.Schema.VoiceRecording

  defschema %{
    title: "VoiceRecordingPage",
    type: :object,
    required: [:data, :meta],
    properties: %{
      data:
        array_of(VoiceRecording,
          description: "Newest first, failed ones only for people who may record"
        ),
      meta: PageMeta
    }
  }
end
