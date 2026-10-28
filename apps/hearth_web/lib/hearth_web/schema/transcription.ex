defmodule HearthWeb.Schema.Transcription do
  use JSV.Schema

  defschema %{
    title: "Transcription",
    type: :object,
    description: "Covers transcripts of recordings and live captions",
    required: [:enabled],
    properties: %{enabled: boolean()}
  }
end
