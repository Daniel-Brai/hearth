defmodule HearthWeb.Schema.VoiceParticipant do
  use JSV.Schema

  alias Hearth.Voice.Participant
  alias HearthWeb.Schema

  defschema %{
    title: "VoiceParticipant",
    type: :object,
    required: ~w[user_id role hand_raised_at self_muted server_muted]a,
    properties: %{
      user_id: uuid(),
      role: Schema.enum_of(Participant, :role),
      hand_raised_at: nullable(string(format: :"date-time")),
      self_muted: boolean(description: "What their own mute button shows"),
      server_muted: boolean(description: "Muted by a host or moderator")
    }
  }
end
