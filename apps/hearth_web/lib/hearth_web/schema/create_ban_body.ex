defmodule HearthWeb.Schema.CreateBanBody do
  use JSV.Schema

  defschema %{
    title: "CreateBanBody",
    type: :object,
    required: [:username, :reason],
    additionalProperties: false,
    properties: %{
      username: string(minLength: 1, description: "With or without the @"),
      reason: string(minLength: 1, maxLength: 500),
      expires_at: nullable(string(format: :"date-time", description: "Null lasts until lifted"))
    }
  }
end
