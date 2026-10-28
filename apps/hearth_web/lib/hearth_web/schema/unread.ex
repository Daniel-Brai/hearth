defmodule HearthWeb.Schema.Unread do
  use JSV.Schema

  defschema %{
    title: "Unread",
    type: :object,
    description: "Only places with something unread are listed",
    required: [:rooms, :conversations],
    properties: %{
      rooms:
        array_of(%{
          type: :object,
          required: [:id, :community_id, :count],
          properties: %{id: uuid(), community_id: uuid(), count: pos_integer()}
        }),
      conversations:
        array_of(%{
          type: :object,
          required: [:id, :count],
          properties: %{id: uuid(), count: pos_integer()}
        })
    }
  }
end
