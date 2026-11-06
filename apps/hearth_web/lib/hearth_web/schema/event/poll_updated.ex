defmodule HearthWeb.Schema.Event.PollUpdated do
  use JSV.Schema

  defschema %{
    title: "PollUpdated",
    type: :object,
    description: "On room:<id> after each vote and when the poll closes, with the new totals",
    required: [:poll_id, :message_id, :room_id, :voters, :counts, :closed_at],
    properties: %{
      poll_id: uuid(),
      message_id: uuid(),
      room_id: uuid(),
      voters: non_neg_integer(),
      counts:
        array_of(%{
          type: :object,
          required: [:option_id, :votes],
          properties: %{option_id: uuid(), votes: non_neg_integer()}
        }),
      closed_at: nullable(string(format: :"date-time"))
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Chat.PollUpdated
end
