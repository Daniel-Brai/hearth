defmodule HearthWeb.Schema.Event.VoiceRecordingChanged do
  use JSV.Schema

  defschema %{
    title: "VoiceRecordingChanged",
    type: :object,
    description:
      "On voice:<id>, community:<id> and the discussed post's post:<id>, fetch it for its addresses",
    required:
      ~w[session_id post_id community_id room_id recording_id status started_by_id started_at]a,
    properties: %{
      session_id: uuid(),
      post_id: nullable(uuid()),
      community_id: uuid(),
      room_id: uuid(),
      recording_id: uuid(),
      status: enum(~w[recording processing ready failed]),
      started_by_id: nullable(uuid()),
      started_at: string(format: :"date-time")
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceRecordingChanged
end
