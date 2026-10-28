defmodule HearthWeb.Schema.Event.MediaReady do
  use JSV.Schema

  defschema %{
    title: "MediaReady",
    type: :object,
    description: "On user:<id>",
    required: [:media_id, :uploader_id],
    properties: %{
      media_id: uuid(),
      uploader_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Media.MediaReady
end
