defmodule HearthWeb.Schema.Post do
  use JSV.Schema

  alias HearthWeb.Schema.Media
  alias HearthWeb.Schema.Reaction
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "Post",
    type: :object,
    required: ~w[
      id
      community_id
      kind_id
      author
      title
      body
      status
      pinned
      locked
      answer_reply_id
      reply_count
      helpful_count
      last_activity_at
      edited_at
      inserted_at
      attachments
      reported
      in_review
      watching
      live
      from_chat
      transcript
      reactions
      seen
      preview_hidden
    ]a,
    properties: %{
      id: uuid(),
      community_id: uuid(),
      kind_id: uuid(),
      author: nullable(UserSummary),
      title: string(),
      body: string(),
      status: enum(~w[published pending removed]),
      pinned: boolean(),
      locked: boolean(),
      answer_reply_id: nullable(uuid()),
      reply_count: non_neg_integer(),
      helpful_count: non_neg_integer(),
      last_activity_at: string(format: :"date-time"),
      edited_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time"),
      attachments: array_of(Media),
      reported: boolean(description: "False signed out"),
      in_review: boolean(description: "Says nothing of who reported it"),
      live:
        nullable(%{
          type: :object,
          description: "Only on a single post",
          required: [:session_id, :room_id, :mode],
          properties: %{session_id: uuid(), room_id: uuid(), mode: enum(~w[stage open])}
        }),
      watching: boolean(description: "False signed out"),
      reactions: array_of(Reaction),
      seen: boolean(description: "The viewer has read it, false signed out"),
      preview_hidden: boolean(description: "Its link card was taken off"),
      transcript:
        nullable(%{
          type: :object,
          description: "Only on a single post, for members, once a live discussion is written up",
          required: [:session_id, :room_name, :duration_ms],
          properties: %{
            session_id: uuid(),
            room_name: string(),
            duration_ms: nullable(integer())
          }
        }),
      from_chat:
        nullable(%{
          type: :object,
          description: "Set when chat messages were promoted into this post",
          required: [:room_id, :message_count, :promoted_by],
          properties: %{
            room_id: nullable(uuid()),
            message_count: pos_integer(),
            promoted_by: nullable(UserSummary)
          }
        })
    }
  }
end
