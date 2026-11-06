defmodule HearthWeb.PollJSON do
  alias Hearth.Chat
  alias HearthWeb.MessageJSON

  def create(%{message: message} = assigns), do: MessageJSON.serialize(message, assigns)
  def show(%{view: view}), do: serialize(view)

  @spec serialize(Chat.poll_view()) :: map()
  def serialize(%{poll: poll, counts: counts, voters: voters, mine: mine}) do
    poll
    |> Map.take(~w[id message_id multiple closes_at closed_at]a)
    |> Map.merge(%{
      voters: voters,
      mine: mine,
      options:
        Enum.map(poll.options, &%{id: &1.id, label: &1.label, votes: Map.get(counts, &1.id, 0)})
    })
  end
end
