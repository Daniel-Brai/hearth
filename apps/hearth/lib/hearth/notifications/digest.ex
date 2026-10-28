defmodule Hearth.Notifications.Digest do
  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Moderation
  alias Hearth.Notifications.CatchUp

  # As many as Catch up shows for each community
  @per_community 3
  # Plenty to rank from, while one busy community can't make it slow
  @most 500

  @spec build(User.t(), :daily | :weekly, DateTime.t()) :: nil | CatchUp.t()
  def build(%User{} = user, period, %DateTime{} = since) do
    communities = Communities.list_joined(user)
    ids = Enum.map(communities, & &1.id)
    posts = user |> Forum.list_unread_since(ids, since, @most) |> without_trouble(user)
    authors = posts |> Enum.map(& &1.author_id) |> Accounts.list_users() |> Map.new(&{&1.id, &1})
    now = DateTime.utc_now()

    by_community = Enum.group_by(posts, & &1.community_id)

    communities
    |> Enum.flat_map(fn community ->
      ranked = by_community |> Map.get(community.id, []) |> Enum.sort_by(&score(&1, now), :desc)

      case ranked do
        [] ->
          []

        [top | _rest] ->
          [
            {score(top, now),
             %{
               community: community,
               posts:
                 ranked
                 |> Enum.take(@per_community)
                 |> Enum.map(&%{post: &1, author: authors[&1.author_id]}),
               more: max(length(ranked) - @per_community, 0)
             }}
          ]
      end
    end)
    |> Enum.sort_by(&elem(&1, 0), :desc)
    |> Enum.map(&elem(&1, 1))
    |> catch_up(period)
  end

  defp catch_up([], _period), do: nil
  defp catch_up(found, period), do: %CatchUp{period: period, communities: found}

  defp without_trouble(posts, user) do
    ids = Enum.map(posts, & &1.id)

    held =
      :post |> Moderation.in_review(ids) |> MapSet.union(Moderation.reported_by(user, :post, ids))

    Enum.reject(posts, &MapSet.member?(held, &1.id))
  end

  defp score(post, now) do
    hours = DateTime.diff(now, post.inserted_at, :minute) / 60

    if(post.pinned_at, do: 1000, else: 0) + post.helpful_count * 3 + post.reply_count * 2 +
      max(0, 72 - hours) / 6
  end
end
