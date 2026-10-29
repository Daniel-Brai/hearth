defmodule HearthWeb.CommunityExtras do
  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.Media
  alias HearthWeb.Authors
  alias HearthWeb.OnlineCounts

  @logo_width 0
  @banner_width 1280

  @spec put([map()], nil | map()) :: [map()]
  def put(communities, viewer) when is_list(communities) do
    logos = communities |> Enum.map(& &1.logo_id) |> Media.image_urls(@logo_width)
    banners = communities |> Enum.map(& &1.banner_id) |> Media.image_urls(@banner_width)
    counts = communities |> Enum.map(& &1.id) |> IAM.member_counts()
    online = communities |> Enum.map(& &1.id) |> OnlineCounts.count()
    owners = communities |> Enum.map(& &1.owner_id) |> Authors.people()
    categories = communities |> Enum.map(& &1.id) |> Communities.category_slugs()

    Enum.map(communities, fn community ->
      community
      |> put_rooms(viewer)
      |> Map.merge(%{
        logo_url: logos[community.logo_id],
        banner_url: banners[community.banner_id],
        member_count: Map.get(counts, community.id, 0),
        online_count: Map.get(online, community.id, 0),
        categories: Map.get(categories, community.id, []),
        owner: owners[community.owner_id]
      })
    end)
  end

  @spec put_one(map(), nil | map()) :: map()
  def put_one(community, viewer), do: [community] |> put(viewer) |> hd()

  defp put_rooms(%{rooms: rooms} = community, _viewer) when not is_list(rooms), do: community

  defp put_rooms(community, viewer),
    do: %{community | rooms: Communities.list_visible_rooms(community, viewer)}
end
