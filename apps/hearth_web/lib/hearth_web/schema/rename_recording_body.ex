defmodule HearthWeb.Schema.RenameRecordingBody do
  use JSV.Schema

  defschema %{
    title: "RenameRecordingBody",
    type: :object,
    required: [:title],
    additionalProperties: false,
    properties: %{
      title: string(minLength: 1, maxLength: 200)
    }
  }
end
