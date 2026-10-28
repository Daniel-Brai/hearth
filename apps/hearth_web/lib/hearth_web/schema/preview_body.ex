defmodule HearthWeb.Schema.PreviewBody do
  use JSV.Schema

  defschema %{
    title: "PreviewBody",
    type: :object,
    required: [:hidden],
    additionalProperties: false,
    properties: %{hidden: boolean(description: "True takes the link card off")}
  }
end
