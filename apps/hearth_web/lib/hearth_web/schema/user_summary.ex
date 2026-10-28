defmodule HearthWeb.Schema.UserSummary do
  use JSV.Schema

  defschema %{
    title: "UserSummary",
    type: :object,
    description: "Null when the account is gone",
    required: ~w[id username display_name avatar_id avatar_url]a,
    properties: %{
      id: uuid(),
      username: string(),
      display_name: nullable(string()),
      avatar_id: nullable(uuid()),
      avatar_url: nullable(string(description: "Null without one or while processing"))
    }
  }
end
