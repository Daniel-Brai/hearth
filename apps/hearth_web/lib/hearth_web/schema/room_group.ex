defmodule HearthWeb.Schema.RoomGroup do
  use JSV.Schema

  defschema %{
    title: "RoomGroup",
    type: :object,
    required: ~w[id community_id name position]a,
    properties: %{
      id: uuid(),
      community_id: uuid(),
      name: string(),
      position: integer()
    }
  }
end
