defmodule HearthWeb.Schema.Event.VoiceSpeakingChanged do
  use JSV.Schema

  defschema %{
    title: "VoiceSpeakingChanged",
    type: :object,
    description: "On voice:<id>, sent at most four times a second",
    required: [:session_id, :user_ids],
    properties: %{session_id: uuid(), user_ids: array_of(uuid())}
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceSpeakingChanged
end
