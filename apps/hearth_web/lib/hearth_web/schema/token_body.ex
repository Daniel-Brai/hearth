defmodule HearthWeb.Schema.TokenBody do
  use JSV.Schema

  defschema %{
    title: "TokenBody",
    type: :object,
    required: [:token],
    additionalProperties: false,
    properties: %{token: string(minLength: 1, maxLength: 100)}
  }
end
