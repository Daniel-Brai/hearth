defmodule HearthWeb.Schema.LinkPreview do
  use JSV.Schema

  defschema %{
    title: "LinkPreview",
    type: :object,
    description:
      "A page's own title, description and image. The image loads from the page's site",
    required: [:url, :site, :title, :description, :image_url],
    properties: %{
      url: string(),
      site: string(),
      title: string(),
      description: nullable(string()),
      image_url: nullable(string())
    }
  }
end
