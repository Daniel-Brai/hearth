defmodule HearthWeb.Schema.Event.ScheduledPostChanged do
  use JSV.Schema

  defschema %{
    title: "ScheduledPostChanged",
    type: :object,
    description:
      "On user:<id> when a scheduled post of theirs is added, moved, sent or fails, so other tabs refetch it",
    required: [:user_id, :scheduled_id],
    properties: %{
      user_id: uuid(),
      scheduled_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Forum.ScheduledPostChanged
end
