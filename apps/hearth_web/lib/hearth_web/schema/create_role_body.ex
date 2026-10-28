defmodule HearthWeb.Schema.CreateRoleBody do
  use JSV.Schema

  defschema %{
    title: "CreateRoleBody",
    type: :object,
    required: [:key, :name],
    additionalProperties: false,
    properties: %{
      key:
        string(
          maxLength: 30,
          description: "Never changes after"
        ),
      name: string(maxLength: 30),
      color: nullable(string(description: "Hex such as #2f6fed")),
      position: integer(minimum: 0),
      permissions: array_of(string())
    }
  }
end
