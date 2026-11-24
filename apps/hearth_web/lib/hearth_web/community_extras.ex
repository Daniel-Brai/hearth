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
    ids = Enum.map(communities, & &1.id)
    images = communities |> Enum.flat_map(&[&1.logo_id, &1.banner_id]) |> Media.get_images()

    logos =
      images
      |> Map.take(Enum.map(communities, & &1.logo_id))
      |> Media.image_urls_from(@logo_width)

    banners =
      images
      |> Map.take(Enum.map(communities, & &1.banner_id))
      |> Media.image_urls_from(@banner_width)

    counts = IAM.member_counts(ids)
    online = OnlineCounts.count(ids)
    owners = communities |> Enum.map(& &1.owner_id) |> Authors.people()
    categories = Communities.category_slugs(ids)

    communities = Enum.map(communities, &put_rooms(&1, viewer))

    groups =
      communities |> Enum.filter(&is_list(&1.rooms)) |> Communities.list_room_groups(viewer)

    Enum.map(communities, fn community ->
      Map.merge(community, %{
        room_groups: Map.get(groups, community.id, []),
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
