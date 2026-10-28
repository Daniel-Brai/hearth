defmodule HearthWeb.Schema.EmailCheckBody do
  use JSV.Schema

  defschema %{
    title: "EmailCheckBody",
    type: :object,
    required: [:emails],
    additionalProperties: false,
    properties: %{
      emails: array_of(string(minLength: 1, maxLength: 254), minItems: 1, maxItems: 50)
    }
  }
end
