defmodule HearthWeb.Schema.CommunityDetail do
  use JSV.Schema

  alias HearthWeb.Schema.Community
  alias HearthWeb.Schema.Membership
  alias HearthWeb.Schema.PostKind

  defschema %{
    title: "CommunityDetail",
    type: :object,
    required: [:community, :kinds, :membership],
    properties: %{
      community: Community,
      kinds: array_of(PostKind),
      membership: nullable(Membership)
    }
  }
end
