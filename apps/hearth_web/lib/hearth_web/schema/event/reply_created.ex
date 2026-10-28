defmodule HearthWeb.Schema.Event.ReplyCreated do
  use JSV.Schema

  defschema %{
    title: "ReplyCreated",
    type: :object,
    description: "On post:<id>",
    required: ~w[
      reply_id
      post_id
      parent_reply_id
      community_id
      author_id
      parent_author_id
      post_author_id
    ]a,
    properties: %{
      reply_id: uuid(),
      post_id: uuid(),
      parent_reply_id: nullable(uuid()),
      community_id: uuid(),
      author_id: uuid(),
      parent_author_id: nullable(uuid()),
      post_author_id: nullable(uuid())
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Forum.ReplyCreated
end
