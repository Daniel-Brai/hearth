defmodule HearthWeb.Schema.Event.EventUpdated do
  use JSV.Schema

  defschema %{
    title: "EventUpdated",
    type: :object,
    description: "On community:<id>, moved is true when its time did",
    required: ~w[event_id community_id moved]a,
    properties: %{
      event_id: uuid(),
      community_id: uuid(),
      moved: boolean()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Events.EventUpdated
end
