defmodule HearthWeb.Schema.MediaUrls do
  use JSV.Schema

  alias HearthWeb.Schema.MediaVariant

  defschema %{
    title: "MediaUrls",
    type: :object,
    description: "Signed, good for at least an hour",
    required: [:original, :download, :variants],
    properties: %{
      original: string(),
      download:
        string(
          description:
            "Saves the file instead of opening it, as the copy with metadata removed for pictures and videos"
        ),
      variants: array_of(MediaVariant)
    }
  }
end
