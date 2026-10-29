defmodule HearthWeb.Schema.Event.EventCancelled do
  use JSV.Schema

  defschema %{
    title: "EventCancelled",
    type: :object,
    description: "On community:<id>",
    required: ~w[event_id community_id room_id cancelled_by_id]a,
    properties: %{
      event_id: uuid(),
      community_id: uuid(),
      room_id: nullable(uuid()),
      cancelled_by_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Events.EventCancelled
end
