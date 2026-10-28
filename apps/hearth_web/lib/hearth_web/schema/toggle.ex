defmodule HearthWeb.Schema.Toggle do
  use JSV.Schema

  defschema %{
    title: "Toggle",
    type: :object,
    required: [:on],
    properties: %{on: boolean()}
  }
end
