defmodule HearthWeb.Schema.Event.VoiceSessionEnded do
  use JSV.Schema

  defschema %{
    title: "VoiceSessionEnded",
    type: :object,
    description:
      "On community:<id>, voice:<id> and the discussed post's post:<id>, lost means its server went away",
    required: [:session_id, :room_id, :community_id, :post_id, :reason],
    properties: %{
      session_id: uuid(),
      room_id: uuid(),
      community_id: uuid(),
      post_id: nullable(uuid()),
      reason: enum(~w[ended lost])
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceSessionEnded
end
