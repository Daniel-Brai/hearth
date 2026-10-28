defmodule HearthWeb.Schema.MemberRolesBody do
  use JSV.Schema

  defschema %{
    title: "MemberRolesBody",
    type: :object,
    required: [:keys],
    additionalProperties: false,
    properties: %{
      keys:
        array_of(string(),
          description: "An empty list means the default role"
        )
    }
  }
end
