defmodule HearthWeb.Schema.Event.VoiceSessionStarted do
  use JSV.Schema

  defschema %{
    title: "VoiceSessionStarted",
    type: :object,
    description: "On community:<id>, and post:<id> for a live discussion",
    required: [:session_id, :room_id, :community_id, :post_id, :host_id, :mode, :topic],
    properties: %{
      session_id: uuid(),
      room_id: uuid(),
      community_id: uuid(),
      post_id: nullable(uuid()),
      host_id: nullable(uuid()),
      mode: enum(~w[stage open]),
      topic: nullable(string())
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceSessionStarted
end
