defmodule HearthWeb.Schema.Event.VoiceParticipantChanged do
  use JSV.Schema

  alias Hearth.Voice.Participant
  alias HearthWeb.Schema

  defschema %{
    title: "VoiceParticipantChanged",
    type: :object,
    description: "On voice:<id>, carries their whole state",
    required: [:session_id, :user_id, :role, :hand_raised_at, :self_muted, :server_muted, :left],
    properties: %{
      session_id: uuid(),
      user_id: uuid(),
      role: nullable(Schema.enum_of(Participant, :role)),
      hand_raised_at: nullable(string(format: :"date-time")),
      self_muted: boolean(),
      server_muted: boolean(),
      left: boolean()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceParticipantChanged
end
