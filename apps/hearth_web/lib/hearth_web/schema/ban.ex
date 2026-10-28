defmodule HearthWeb.Schema.Ban do
  use JSV.Schema

  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "Ban",
    type: :object,
    description: "Null expires_at lasts until lifted",
    required: ~w[id community_id user banned_by reason expires_at lifted_at inserted_at]a,
    properties: %{
      id: uuid(),
      community_id: uuid(),
      user: nullable(UserSummary),
      banned_by: nullable(UserSummary),
      reason: nullable(string()),
      expires_at: nullable(string(format: :"date-time")),
      lifted_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time")
    }
  }
end
