defmodule HearthWeb.CommunityJSON do
  alias HearthWeb.RoomJSON
  alias HearthWeb.UserJSON

  @fields ~w[
    id
    slug
    name
    tagline
    description
    hue
    logo_id
    banner_id
    visibility
    moderation
    welcome_message
    template
    owner_id
  ]a

  def index(%{communities: communities}), do: Enum.map(communities, &serialize/1)

  def create(%{community: community}), do: serialize(community)

  def show(%{community: community, kinds: kinds, membership: membership}) do
    %{
      community: serialize(community),
      kinds: Enum.map(kinds, &kind/1),
      membership: membership(membership)
    }
  end

  def outline(%{community: community}) do
    %{
      community:
        community
        |> serialize()
        |> Map.merge(%{description: nil, welcome_message: nil, links: [], rooms: []}),
      kinds: [],
      membership: nil
    }
  end

  def update(%{community: community}), do: serialize(community)

  def slug(%{slug: slug}), do: %{slug: slug}

  def join(%{membership: membership}), do: membership(membership)

  @spec serialize(map()) :: map()
  def serialize(community) do
    community
    |> Map.take(@fields)
    |> Map.merge(
      Map.take(community, ~w[logo_url banner_url member_count online_count categories]a)
    )
    |> Map.put(:owner, UserJSON.summary(community.owner))
    |> Map.put(:links, Enum.map(community.links, &Map.take(&1, [:url, :label])))
    |> Map.put(
      :rooms,
      community.rooms |> Enum.reject(& &1.archived_at) |> Enum.map(&RoomJSON.serialize/1)
    )
  end

  defp kind(kind) do
    Map.take(
      kind,
      ~w[id key label icon hue description title_hint body_hint answers postable position]a
    )
  end

  defp membership(nil), do: nil

  defp membership(membership) do
    %{
      roles: Enum.map(membership.roles, &Map.take(&1, ~w[key name color]a)),
      permissions: membership.permissions,
      joined_at: membership.joined_at
    }
  end
end
