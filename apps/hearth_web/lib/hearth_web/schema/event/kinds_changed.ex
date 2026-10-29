defmodule HearthWeb.Schema.Event.KindsChanged do
  use JSV.Schema

  defschema %{
    title: "KindsChanged",
    type: :object,
    description: "On community:<id>",
    required: [:community_id],
    properties: %{community_id: uuid()}
  }

  @spec event() :: module()
  def event, do: Hearth.Forum.KindsChanged
end
