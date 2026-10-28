defmodule HearthWeb.Schema.Role do
  use JSV.Schema

  defschema %{
    title: "Role",
    type: :object,
    required: ~w[id key name color position is_default is_system permissions]a,
    properties: %{
      id: uuid(),
      key: string(description: "Stays the same when the role is renamed"),
      name: string(),
      color: nullable(string(description: "Hex such as #2f6fed")),
      position: integer(),
      is_default: boolean(),
      is_system: boolean(description: "Can't be deleted"),
      permissions: array_of(string())
    }
  }
end
