defmodule HearthWeb.ConversationJSON do
  alias Hearth.Common.T
  alias HearthWeb.UserJSON

  def index(%{conversations: conversations} = assigns),
    do: Enum.map(conversations, &serialize(&1, assigns))

  def create(%{conversation: conversation} = assigns), do: serialize(conversation, assigns)

  @spec serialize(map(), map()) :: map()
  def serialize(conversation, %{people: people}) do
    member_ids = member_ids(conversation)

    conversation
    |> Map.take(~w[id kind name]a)
    |> Map.merge(%{
      member_ids: member_ids,
      members: member_ids |> Enum.map(&UserJSON.summary(people[&1])) |> Enum.reject(&is_nil/1)
    })
  end

  @spec member_ids(map()) :: [T.id()]
  def member_ids(%{members: members}) when is_list(members), do: Enum.map(members, & &1.user_id)
  def member_ids(_conversation), do: []
end
