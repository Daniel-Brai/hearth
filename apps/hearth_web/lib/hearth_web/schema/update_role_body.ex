defmodule HearthWeb.Schema.UpdateRoleBody do
  use JSV.Schema

  defschema %{
    title: "UpdateRoleBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      name: string(maxLength: 30),
      color: nullable(string(description: "Hex such as #2f6fed")),
      position: integer(minimum: 0),
      permissions: array_of(string(), description: "Replaces what it had")
    }
  }
end
