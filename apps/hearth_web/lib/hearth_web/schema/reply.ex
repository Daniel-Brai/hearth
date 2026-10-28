defmodule HearthWeb.Schema.Reply do
  use JSV.Schema

  alias HearthWeb.Schema.Media
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "Reply",
    type: :object,
    required: ~w[
      id
      post_id
      parent_reply_id
      author
      body
      depth
      child_count
      descendant_count
      helpful_count
      status
      deleted
      edited_at
      inserted_at
      attachments
    ]a,
    properties: %{
      id: uuid(),
      post_id: uuid(),
      parent_reply_id: nullable(uuid()),
      author: nullable(UserSummary),
      body: nullable(string(description: "Null once deleted or removed")),
      depth: non_neg_integer(),
      child_count: non_neg_integer(),
      descendant_count: non_neg_integer(),
      helpful_count: non_neg_integer(),
      status: enum(~w[published pending removed]),
      deleted: boolean(description: "Kept because it has answers"),
      edited_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time"),
      attachments: array_of(Media)
    }
  }
end
