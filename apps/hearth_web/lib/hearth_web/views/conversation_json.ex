defmodule HearthWeb.ConversationJSON do
  alias HearthWeb.UserJSON

  def index(%{conversations: conversations} = assigns),
    do: Enum.map(conversations, &serialize(&1, assigns))

  def create(%{conversation: conversation} = assigns), do: serialize(conversation, assigns)

  @spec serialize(map(), map()) :: map()
  def serialize(conversation, assigns) do
    member_ids = member_ids(conversation)
    people = Map.get(assigns, :people, %{})

    conversation
    |> Map.take(~w[id kind name]a)
    |> Map.merge(%{
      member_ids: member_ids,
      members: for(id <- member_ids, person = people[id], do: UserJSON.summary(person))
    })
  end

  @spec member_ids(map()) :: [String.t()]
  def member_ids(%{members: members}) when is_list(members), do: Enum.map(members, & &1.user_id)
  def member_ids(_conversation), do: []
end
