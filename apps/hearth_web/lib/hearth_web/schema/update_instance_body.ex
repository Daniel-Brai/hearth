defmodule HearthWeb.Schema.UpdateInstanceBody do
  use JSV.Schema

  defschema %{
    title: "UpdateInstanceBody",
    type: :object,
    required: [:community_creation],
    additionalProperties: false,
    properties: %{
      community_creation: enum(~w[admins request anyone])
    }
  }
end
