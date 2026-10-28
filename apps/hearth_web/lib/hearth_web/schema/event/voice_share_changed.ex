defmodule HearthWeb.Schema.Event.VoiceShareChanged do
  use JSV.Schema

  defschema %{
    title: "VoiceShareChanged",
    type: :object,
    description: "On voice:<id>",
    required: [:session_id, :user_id],
    properties: %{
      session_id: uuid(),
      user_id: nullable(uuid(description: "Null when nobody does"))
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceShareChanged
end
