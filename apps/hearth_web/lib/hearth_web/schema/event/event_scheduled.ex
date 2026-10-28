defmodule HearthWeb.Schema.Event.EventScheduled do
  use JSV.Schema

  defschema %{
    title: "EventScheduled",
    type: :object,
    description: "On community:<id>",
    required: ~w[event_id community_id host_id]a,
    properties: %{
      event_id: uuid(),
      community_id: uuid(),
      host_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Events.EventScheduled
end
