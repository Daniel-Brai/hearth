defmodule HearthWeb.Schema.SingleUpload do
  use JSV.Schema

  defschema %{
    title: "SingleUpload",
    type: :object,
    description: "PUT the file to url with exactly these headers",
    required: [:url, :headers],
    properties: %{
      url: string(),
      headers: %{type: :object, additionalProperties: string()}
    }
  }
end
