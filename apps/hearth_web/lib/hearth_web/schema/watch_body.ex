defmodule HearthWeb.Schema.WatchBody do
  use JSV.Schema

  defschema %{
    title: "WatchBody",
    type: :object,
    required: [:watching],
    additionalProperties: false,
    properties: %{watching: boolean()}
  }
end
