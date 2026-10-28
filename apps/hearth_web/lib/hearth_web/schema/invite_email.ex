defmodule HearthWeb.Schema.InviteEmail do
  use JSV.Schema

  defschema %{
    title: "InviteEmail",
    type: :object,
    required: ~w[id email role_key status inserted_at]a,
    properties: %{
      id: uuid(),
      email: string(),
      role_key: string(),
      status: enum(~w[pending accepted declined revoked]),
      inserted_at: string(format: :"date-time")
    }
  }
end
