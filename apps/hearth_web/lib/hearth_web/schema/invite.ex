defmodule HearthWeb.Schema.Invite do
  use JSV.Schema

  defschema %{
    title: "Invite",
    type: :object,
    required:
      ~w[id code role_key max_uses uses_count expires_at revoked_at created_by_id inserted_at]a,
    properties: %{
      id: uuid(),
      code: string(),
      role_key: string(),
      max_uses: nullable(pos_integer()),
      uses_count: non_neg_integer(),
      expires_at: nullable(string(format: :"date-time")),
      revoked_at: nullable(string(format: :"date-time")),
      created_by_id: uuid(),
      inserted_at: string(format: :"date-time")
    }
  }
end
