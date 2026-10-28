defmodule HearthWeb.Schema.PartUrls do
  use JSV.Schema

  defschema %{
    title: "PartUrls",
    type: :object,
    required: [:urls],
    properties: %{
      urls: %{
        type: :object,
        description: "A signed PUT URL for each part number",
        additionalProperties: string()
      }
    }
  }
end
