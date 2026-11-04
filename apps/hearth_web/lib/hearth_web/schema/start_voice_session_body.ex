defmodule HearthWeb.Schema.StartVoiceSessionBody do
  use JSV.Schema

  alias Hearth.Voice.Session
  alias HearthWeb.Schema

  defschema %{
    title: "StartVoiceSessionBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      mode: Schema.enum_of(Session, :mode, description: "Open when left out"),
      topic: nullable(string(maxLength: 200))
    }
  }
end
