defmodule HearthWeb.Schema.ChatMessage do
  use JSV.Schema

  alias HearthWeb.Schema.Media
  alias HearthWeb.Schema.Reaction
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "ChatMessage",
    type: :object,
    required: ~w[
      id
      room_id
      conversation_id
      reply_to_id
      author
      body
      depth
      child_count
      status
      kind
      post_id
      deleted
      edited_at
      inserted_at
      attachments
      reactions
      preview_hidden
      mentions_all
    ]a,
    properties: %{
      id: uuid(),
      room_id: nullable(uuid()),
      conversation_id: nullable(uuid()),
      reply_to_id: nullable(uuid()),
      author: nullable(UserSummary),
      body: nullable(string(description: "Null once deleted or removed")),
      depth: non_neg_integer(),
      child_count: non_neg_integer(),
      status: enum(~w[published pending removed]),
      kind:
        enum(~w[text promoted action sound],
          description:
            "A promoted message is the room's note about a new post, an action is a /me line and a sound is a /play whose body is its name"
        ),
      post_id: nullable(uuid(description: "The post a promoted note points at")),
      deleted: boolean(),
      edited_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time"),
      attachments: array_of(Media),
      reactions: array_of(Reaction, description: "Empty once deleted or removed"),
      preview_hidden: boolean(description: "Its link card was taken off"),
      mentions_all: boolean(description: "Its @all notified everyone who can see the room")
    }
  }
end
