defmodule HearthWeb.Schema.QueueSubject do
  use JSV.Schema

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
      type: enum(~w[post reply message]),
      id: uuid(),
      author: nullable(UserSummary),
      title: nullable(string()),
      body: string(),
      status: enum(~w[published pending removed]),
      post_id: nullable(uuid()),
      room_id: nullable(uuid()),
      conversation_id: nullable(uuid()),
      inserted_at: string(format: :"date-time"),
      attachments: array_of(Media)
    }
  }
end
