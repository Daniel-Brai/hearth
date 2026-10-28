defmodule HearthWeb.PeopleJSON do
  alias HearthWeb.UserJSON

  def index(%{people: people} = assigns), do: Enum.map(people, &person(&1, assigns))

  # Everyone listed shares a community with the viewer so members counts as seen
  defp person(%{privacy: privacy} = user, %{shared: shared, online: online}) do
    user
    |> UserJSON.summary()
    |> Map.merge(%{
      online: privacy.presence != :nobody and MapSet.member?(online, user.id),
      last_seen_at: if(privacy.last_seen == :nobody, do: nil, else: user.last_seen_at),
      community_ids: if(privacy.show_communities == :nobody, do: [], else: shared[user.id])
    })
  end
end
