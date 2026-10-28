defmodule HearthWeb.Schema.Voice do
  use JSV.Schema

  defschema %{
    title: "Voice",
    type: :object,
    description: "Needs a node running rtc with a public address",
    required: [:enabled],
    properties: %{enabled: boolean()}
  }
end
