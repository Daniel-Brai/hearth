defmodule HearthWeb.Schema.Event.VoiceReaction do
  use JSV.Schema

  defschema %{
    title: "VoiceReaction",
    type: :object,
    description: "On voice:<id>, emoji is a shortcode such as :tada:",
    required: [:session_id, :user_id, :emoji],
    properties: %{session_id: uuid(), user_id: uuid(), emoji: string()}
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceReaction
end
