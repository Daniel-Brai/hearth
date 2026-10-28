defmodule HearthWeb.Schema.MuteBody do
  use JSV.Schema

  defschema %{
    title: "MuteBody",
    type: :object,
    required: [:muted],
    additionalProperties: false,
    properties: %{muted: boolean()}
  }
end
