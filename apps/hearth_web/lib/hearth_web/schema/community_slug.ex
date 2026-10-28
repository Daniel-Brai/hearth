defmodule HearthWeb.Schema.CommunitySlug do
  use JSV.Schema

  defschema %{
    title: "CommunitySlug",
    type: :object,
    required: [:slug],
    properties: %{slug: string(description: "Goes after /c/ in the community's address")}
  }
end
