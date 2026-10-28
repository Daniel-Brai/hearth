defmodule HearthWeb.Schema.Errors do
  use JSV.Schema

  defschema %{
    title: "Errors",
    type: :object,
    required: [:message, :errors],
    properties: %{
      message: string(),
      errors: %{
        type: :object,
        description: "Each failing field's messages, keyed by its path in the body",
        additionalProperties: array_of(string(), minItems: 1)
      }
    }
  }
end
