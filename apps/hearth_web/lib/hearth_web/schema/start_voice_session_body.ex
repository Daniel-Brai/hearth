defmodule HearthWeb.Schema.StartVoiceSessionBody do
  use JSV.Schema

  defschema %{
    title: "StartVoiceSessionBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      mode: enum(~w[stage open], description: "Open when left out"),
      topic: nullable(string(maxLength: 200))
    }
  }
end
