defmodule HearthWeb.Schema.Event.VoiceRecordingDeleted do
  use JSV.Schema

  defschema %{
    title: "VoiceRecordingDeleted",
    type: :object,
    description: "On community:<id> and the discussed post's post:<id>, drop it from any list",
    required: ~w[recording_id session_id post_id community_id room_id]a,
    properties: %{
      recording_id: uuid(),
      session_id: uuid(),
      post_id: nullable(uuid()),
      community_id: uuid(),
      room_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceRecordingDeleted
end
