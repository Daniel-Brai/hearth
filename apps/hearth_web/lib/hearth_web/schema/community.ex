defmodule HearthWeb.Schema.Community do
  use JSV.Schema

  alias HearthWeb.Schema.Link
  alias HearthWeb.Schema.Room
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "Community",
    type: :object,
    required: ~w[
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
      owner
      logo_url
      banner_url
      member_count
      links
      rooms
    ]a,
    properties: %{
      id: uuid(),
      slug: string(),
      name: string(),
      tagline: nullable(string()),
      description: nullable(string()),
      hue: enum(~w[ink blue violet purple pink red orange yellow green aqua]),
      logo_id: nullable(uuid()),
      banner_id: nullable(uuid()),
      visibility: enum(~w[public_indexed public invite_only private]),
      moderation: enum(~w[full reports none]),
      welcome_message: nullable(string()),
      template: string(),
      owner_id: nullable(uuid()),
      owner: nullable(UserSummary),
      logo_url: nullable(string(description: "Null without one or while processing")),
      banner_url: nullable(string(description: "Null without one or while processing")),
      member_count: non_neg_integer(),
      links: array_of(Link),
      rooms: array_of(Room)
    }
  }
end
