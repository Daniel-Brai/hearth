defmodule HearthWeb.Schema.Profile do
  use JSV.Schema

  alias HearthWeb.Schema.Link
  alias HearthWeb.Schema.ProfileCounts

  defschema %{
    title: "Profile",
    type: :object,
    required: ~w[
      id
      username
      display_name
      avatar_id
      avatar_url
      bio
      pronouns
      location
      links
      joined_at
      counts
    ]a,
    properties: %{
      id: uuid(),
      username: string(),
      display_name: nullable(string(description: "Null when they show only their username")),
      avatar_id: nullable(uuid()),
      avatar_url: nullable(string()),
      bio: nullable(string()),
      pronouns: nullable(string()),
      location: nullable(string()),
      links: array_of(Link),
      joined_at: string(format: :"date-time"),
      counts: ProfileCounts
    }
  }
end
