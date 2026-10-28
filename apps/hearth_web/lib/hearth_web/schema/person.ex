defmodule HearthWeb.Schema.Person do
  use JSV.Schema

  defschema %{
    title: "Person",
    type: :object,
    required:
      ~w[id username display_name avatar_id avatar_url online last_seen_at community_ids]a,
    properties: %{
      id: uuid(),
      username: string(),
      display_name: nullable(string()),
      avatar_id: nullable(uuid()),
      avatar_url: nullable(string()),
      online: boolean(description: "An app is open now"),
      last_seen_at:
        nullable(string(format: :"date-time", description: "When an app last opened or closed")),
      community_ids: array_of(uuid(), description: "The communities they share with me")
    }
  }
end
