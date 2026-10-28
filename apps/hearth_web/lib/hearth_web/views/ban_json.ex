defmodule HearthWeb.BanJSON do
  alias HearthWeb.UserJSON

  @fields ~w[id community_id reason expires_at lifted_at inserted_at]a

  def index(%{bans: bans, people: people}), do: Enum.map(bans, &serialize(&1, people))
  def show(%{ban: ban, people: people}), do: serialize(ban, people)

  defp serialize(ban, people) do
    ban
    |> Map.take(@fields)
    |> Map.merge(%{
      user: UserJSON.summary(people[ban.user_id]),
      banned_by: UserJSON.summary(people[ban.banned_by_id])
    })
  end
end
