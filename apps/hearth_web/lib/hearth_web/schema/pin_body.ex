defmodule HearthWeb.Schema.PinBody do
  use JSV.Schema

  defschema %{
    title: "PinBody",
    type: :object,
    required: [:pinned],
    additionalProperties: false,
    properties: %{pinned: boolean()}
  }
end
