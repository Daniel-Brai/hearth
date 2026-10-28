defmodule HearthWeb.Schema.Event.MediaFailed do
  use JSV.Schema

  defschema %{
    title: "MediaFailed",
    type: :object,
    description: "On user:<id>",
    required: ~w[media_id uploader_id failure]a,
    properties: %{
      media_id: uuid(),
      uploader_id: uuid(),
      failure: string()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Media.MediaFailed
end
