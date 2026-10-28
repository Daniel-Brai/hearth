defmodule HearthWeb.Schema.VoiceState do
  use JSV.Schema

  alias HearthWeb.Schema.VoiceParticipant
  alias HearthWeb.Schema.VoiceRecordingNow
  alias HearthWeb.Schema.VoiceSession

  defschema %{
    title: "VoiceState",
    type: :object,
    required: ~w[session host_tools may_record recording share hands speaking participants]a,
    properties: %{
      session: VoiceSession,
      host_tools: boolean(description: "For the signed in person"),
      may_record: boolean(description: "For the signed in person"),
      recording: nullable(VoiceRecordingNow),
      share: nullable(uuid(description: "Null when nobody shares")),
      hands: array_of(uuid(), description: "Longest waiting first"),
      speaking: array_of(uuid()),
      participants: array_of(VoiceParticipant)
    }
  }
end
