defmodule HearthWeb.Schema.ModeratedContent do
  use JSV.Schema

  alias Hearth.Forum.Post
  alias Hearth.Moderation.Item
  alias HearthWeb.Schema

  defschema %{
    title: "ModeratedContent",
    type: :object,
    required: [:subject_type, :subject_id, :status],
    properties: %{
      subject_type: Schema.enum_of(Item, :subject_type),
      subject_id: uuid(),
      status: Schema.enum_of(Post, :status)
    }
  }
end
