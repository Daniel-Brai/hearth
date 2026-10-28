defmodule HearthWeb.Schema.Me do
  use JSV.Schema

  defschema %{
    title: "Me",
    type: :object,
    required: ~w[
      id
      username
      display_name
      email
      avatar_id
      avatar_url
      bio
      pronouns
      location
      timezone
      locale
      links
      privacy
      settings
      is_instance_admin
    ]a,
    properties: %{
      id: uuid(),
      username: string(),
      display_name: nullable(string()),
      email: string(),
      avatar_id: nullable(uuid()),
      avatar_url: nullable(string(description: "Null without one or while processing")),
      bio: nullable(string()),
      pronouns: nullable(string()),
      location: nullable(string()),
      timezone: nullable(string()),
      locale: nullable(string()),
      links: array_of(HearthWeb.Schema.Link),
      privacy: HearthWeb.Schema.Privacy,
      settings: HearthWeb.Schema.Settings,
      is_instance_admin: boolean()
    }
  }
end
