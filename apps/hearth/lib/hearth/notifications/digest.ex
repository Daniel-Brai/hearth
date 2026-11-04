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
    communities = user |> Communities.list_joined() |> Map.new(&{&1.id, &1})

    posts =
      user
      |> Forum.list_unread_since(Map.keys(communities), since, @most)
      |> without_trouble(user)
      |> rank(DateTime.utc_now())

    authors = posts |> Enum.map(& &1.author_id) |> Accounts.list_users() |> Map.new(&{&1.id, &1})
    by_community = Enum.group_by(posts, & &1.community_id)

    # Posts come best first so communities follow the order of their best post
    posts
    |> Enum.map(& &1.community_id)
    |> Enum.uniq()
    |> Enum.map(&section(communities[&1], by_community[&1], authors))
    |> catch_up(period)
  end

  defp section(community, posts, authors) do
    %{
      community: community,
      posts:
        posts
        |> Enum.take(@per_community)
        |> Enum.map(&%{post: &1, author: authors[&1.author_id]}),
      more: max(length(posts) - @per_community, 0)
    }
  end

  defp rank(posts, now), do: Enum.sort_by(posts, &score(&1, now), :desc)

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
