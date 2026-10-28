defmodule HearthWeb.Schema.MemberMatch do
  use JSV.Schema

  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "MemberMatch",
    type: :object,
    required: [:user, :role_keys],
    properties: %{user: UserSummary, role_keys: array_of(string())}
  }
end
