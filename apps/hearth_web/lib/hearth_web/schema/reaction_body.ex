defmodule HearthWeb.Schema.ReactionBody do
  use JSV.Schema

  defschema %{
    title: "ReactionBody",
    type: :object,
    required: [:emoji],
    additionalProperties: false,
    properties: %{emoji: string(minLength: 1, maxLength: 32)}
  }
end
