defmodule HearthWeb.Schema.CommunityRequest do
  use JSV.Schema

  alias Hearth.Communities.Request
  alias HearthWeb.Schema
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
      hue: Schema.enum_of(Request, :hue),
      visibility: Schema.enum_of(Request, :visibility),
      template: string(),
      note: nullable(string()),
      status: Schema.enum_of(Request, :status),
      requester: nullable(UserSummary),
      community_id: nullable(uuid()),
      community_slug: nullable(string()),
      decided_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time")
    }
  }
end
