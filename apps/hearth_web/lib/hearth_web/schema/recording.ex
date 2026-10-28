defmodule HearthWeb.Schema.Recording do
  use JSV.Schema

  defschema %{
    title: "Recording",
    type: :object,
    description: "Needs voice, a node making videos and ffmpeg",
    required: [:enabled],
    properties: %{enabled: boolean()}
  }
end
