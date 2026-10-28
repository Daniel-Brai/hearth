defmodule HearthWeb.Schema.Event.VoiceAttendance do
  use JSV.Schema

  defschema %{
    title: "VoiceAttendance",
    type: :object,
    description: "On community:<id> whenever someone joins, leaves or drops out of a live room",
    required: [:session_id, :room_id, :community_id, :people, :user_ids],
    properties: %{
      session_id: uuid(),
      room_id: uuid(),
      community_id: uuid(),
      people: integer(minimum: 0),
      user_ids: array_of(uuid())
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Voice.VoiceAttendance
end
