defmodule HearthWeb.Schema.BanAuthorBody do
  use JSV.Schema

  defschema %{
    title: "BanAuthorBody",
    type: :object,
    required: [:reason],
    additionalProperties: false,
    properties: %{
      reason: string(minLength: 1, maxLength: 500),
      expires_at: nullable(string(format: :"date-time", description: "Null lasts until lifted"))
    }
  }
end
