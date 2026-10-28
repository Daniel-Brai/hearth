defmodule HearthWeb.Schema.Event.VoiceRecordingRenamed do
  use JSV.Schema

  defschema %{
    title: "VoiceRecordingRenamed",
    type: :object,
    description:
      "On community:<id> and the discussed post's post:<id>, show its new title in any list",
    required: ~w[recording_id title session_id post_id community_id room_id]a,
    properties: %{
      recording_id: uuid(),
      title: string(),
      session_id: uuid(),
      post_id: nullable(uuid()),
      community_id: uuid(),
      room_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceRecordingRenamed
end
