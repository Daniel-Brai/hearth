defmodule HearthWeb.Schema.Event.AnswerMarked do
  use JSV.Schema

  defschema %{
    title: "AnswerMarked",
    type: :object,
    description: "On post:<id>",
    required: ~w[post_id reply_id reply_author_id]a,
    properties: %{
      post_id: uuid(),
      reply_id: uuid(),
      reply_author_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Forum.AnswerMarked
end
