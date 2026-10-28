defmodule HearthWeb.UserJSON do
  alias HearthWeb.PageJSON
  alias HearthWeb.PostJSON
  alias HearthWeb.ReplyJSON

  @profile ~w[id username display_name avatar_id avatar_url bio pronouns location]a

  @spec summary(nil | map()) :: nil | map()
  def summary(nil), do: nil
  def summary(user), do: Map.take(user, ~w[id username display_name avatar_id avatar_url]a)

  def index(%{users: users}), do: Enum.map(users, &summary/1)

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
end
