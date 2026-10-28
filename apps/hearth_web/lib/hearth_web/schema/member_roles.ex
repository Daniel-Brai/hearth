defmodule HearthWeb.Schema.MemberRoles do
  use JSV.Schema

  defschema %{
    title: "MemberRoles",
    type: :object,
    required: [:user_id, :keys],
    properties: %{
      user_id: string(format: :uuid),
      keys: array_of(string())
    }
  }
end
