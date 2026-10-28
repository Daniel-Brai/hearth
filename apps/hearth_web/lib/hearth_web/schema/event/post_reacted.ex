defmodule HearthWeb.Schema.Event.PostReacted do
  use JSV.Schema

  defschema %{
    title: "PostReacted",
    type: :object,
    description: "On post:<id>, with the emoji's new count",
    required: ~w[post_id community_id user_id emoji on count]a,
    properties: %{
      post_id: uuid(),
      community_id: uuid(),
      user_id: uuid(),
      emoji: string(),
      on: boolean(description: "Added rather than taken back"),
      count: non_neg_integer()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Forum.PostReacted
end
