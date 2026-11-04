defmodule HearthWeb.Schema.QueueSubject do
  use JSV.Schema

  alias Hearth.Forum.Post
  alias Hearth.Moderation.Item
  alias HearthWeb.Schema
  alias HearthWeb.Schema.Media
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "QueueSubject",
    type: :object,
    description: "Shown whole to moderators whatever its status",
    required: ~w[
      type
      id
      author
      title
      body
      status
      post_id
      room_id
      conversation_id
      inserted_at
      attachments
    ]a,
    properties: %{
      type: Schema.enum_of(Item, :subject_type),
      id: uuid(),
      author: nullable(UserSummary),
      title: nullable(string()),
      body: string(),
      status: Schema.enum_of(Post, :status),
      post_id: nullable(uuid()),
      room_id: nullable(uuid()),
      conversation_id: nullable(uuid()),
      inserted_at: string(format: :"date-time"),
      attachments: array_of(Media)
    }
  }
end
