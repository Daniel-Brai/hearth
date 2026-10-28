defmodule HearthWeb.CommunityExtras do
  alias Hearth.IAM
  alias Hearth.Media
  alias HearthWeb.Authors

  @logo_width 0
  @banner_width 1280

  @spec put([map()]) :: [map()]
  def put(communities) when is_list(communities) do
    logos = communities |> Enum.map(& &1.logo_id) |> Media.image_urls(@logo_width)
    banners = communities |> Enum.map(& &1.banner_id) |> Media.image_urls(@banner_width)
    counts = communities |> Enum.map(& &1.id) |> IAM.member_counts()
    owners = communities |> Enum.map(& &1.owner_id) |> Authors.people()

    Enum.map(communities, fn community ->
      Map.merge(community, %{
        logo_url: logos[community.logo_id],
        banner_url: banners[community.banner_id],
        member_count: Map.get(counts, community.id, 0),
        owner: owners[community.owner_id]
      })
    end)
  end

  @spec put_one(map()) :: map()
  def put_one(community), do: [community] |> put() |> hd()
end
