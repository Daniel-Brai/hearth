defmodule HearthWeb.Schema.CodeBody do
  use JSV.Schema

  defschema %{
    title: "CodeBody",
    type: :object,
    required: [:code],
    additionalProperties: false,
    properties: %{code: string(pattern: "^[0-9]{6}$")}
  }
end
