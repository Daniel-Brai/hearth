defmodule HearthWeb.Schema.Event.PostCreated do
  use JSV.Schema

  defschema %{
    title: "PostCreated",
    type: :object,
    description: "On community:<id>",
    required: ~w[post_id community_id author_id]a,
    properties: %{
      post_id: uuid(),
      community_id: uuid(),
      author_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Forum.PostCreated
end
