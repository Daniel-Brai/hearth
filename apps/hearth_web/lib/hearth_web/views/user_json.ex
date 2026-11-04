defmodule HearthWeb.UserJSON do
  alias HearthWeb.PageJSON
  alias HearthWeb.PostJSON
  alias HearthWeb.ReplyJSON

  @profile ~w[id username display_name avatar_id avatar_url bio pronouns location]a

  @spec summary(nil | map()) :: nil | map()
  def summary(nil), do: nil
  def summary(user), do: Map.take(user, ~w[id username display_name avatar_id avatar_url]a)

  def index(%{people: people} = assigns), do: Enum.map(people, &person(&1, assigns))

  def show(%{user: user, counts: counts}) do
    user
    |> Map.take(@profile)
    |> Map.put(:links, Enum.map(user.links, &Map.take(&1, [:url, :label])))
    |> Map.put(:joined_at, user.inserted_at)
    |> Map.put(:counts, counts)
  end

  def posts(assigns), do: PostJSON.index(assigns)

  def replies(%{page: page, posts: posts} = assigns) do
    %{data: Enum.map(page.data, &authored(&1, posts, assigns)), meta: PageJSON.meta(page.meta)}
  end

  defp authored(reply, posts, assigns) do
    post = Map.fetch!(posts, reply.post_id)

    %{
      reply: ReplyJSON.serialize(reply, assigns),
      post: Map.take(post, ~w[id title community_id]a),
      answer: post.answer_reply_id == reply.id
    }
  end

  def available(%{available: available}), do: %{available: available}

  # A setting for members shows only to someone who shares a community with the person
  defp person(%{privacy: privacy} = user, %{shared: shared, online: online}) do
    communities = shared[user.id]

    user
    |> summary()
    |> Map.merge(%{
      online: shows?(privacy.presence, communities) and MapSet.member?(online, user.id),
      last_seen_at: if(shows?(privacy.last_seen, communities), do: user.last_seen_at),
      community_ids:
        if(shows?(privacy.show_communities, communities), do: communities || [], else: [])
    })
  end

  defp shows?(:nobody, _communities), do: false
  defp shows?(:everyone, _communities), do: true
  defp shows?(_members, communities), do: communities != nil
end
