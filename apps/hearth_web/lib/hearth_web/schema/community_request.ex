defmodule HearthWeb.Schema.CommunityRequest do
  use JSV.Schema

  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "CommunityRequest",
    type: :object,
    description: "community_id and community_slug are set once approved",
    required: ~w[
      id
      name
      tagline
      description
      hue
      visibility
      template
      note
      status
      requester
      community_id
      community_slug
      decided_at
      inserted_at
    ]a,
    properties: %{
      id: uuid(),
      name: string(),
      tagline: nullable(string()),
      description: nullable(string()),
      hue: enum(~w[ink blue violet purple pink red orange yellow green aqua]),
      visibility: enum(~w[public_indexed public invite_only private]),
      template: string(),
      note: nullable(string()),
      status: enum(~w[pending approved declined]),
      requester: nullable(UserSummary),
      community_id: nullable(uuid()),
      community_slug: nullable(string()),
      decided_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time")
    }
  }
end
