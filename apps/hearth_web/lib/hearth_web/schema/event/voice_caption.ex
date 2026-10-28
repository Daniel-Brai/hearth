defmodule HearthWeb.Schema.Event.VoiceCaption do
  use JSV.Schema

  defschema %{
    title: "VoiceCaption",
    type: :object,
    description: "On voice:<id> while someone there has captions on, a line one speaker said",
    required: [:session_id, :user_id, :text],
    properties: %{
      session_id: uuid(),
      user_id: uuid(),
      text: string()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceCaption
end
