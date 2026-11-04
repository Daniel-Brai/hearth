defmodule HearthWeb.Schema.Event.ScheduledMessageChanged do
  use JSV.Schema

  defschema %{
    title: "ScheduledMessageChanged",
    type: :object,
    description:
      "On user:<id> when a scheduled message of theirs is added, moved, sent or fails, so other tabs refetch it",
    required: [:user_id, :scheduled_id],
    properties: %{
      user_id: uuid(),
      scheduled_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Chat.ScheduledMessageChanged
end
