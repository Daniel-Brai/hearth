defmodule HearthWeb.Schema.LockBody do
  use JSV.Schema

  defschema %{
    title: "LockBody",
    type: :object,
    required: [:locked],
    additionalProperties: false,
    properties: %{locked: boolean()}
  }
end
