defmodule HearthWeb.ReplyJSON do
  alias HearthWeb.PageJSON
  alias HearthWeb.UserJSON

  @fields ~w[
    id
    post_id
    parent_reply_id
    depth
    child_count
    descendant_count
    helpful_count
    status
    edited_at
    inserted_at
  ]a

  def index(%{page: page} = assigns) do
    %{data: Enum.map(page.data, &serialize(&1, assigns)), meta: PageJSON.meta(page.meta)}
  end

  def create(%{reply: reply} = assigns), do: serialize(reply, assigns)
  def update(%{reply: reply} = assigns), do: serialize(reply, assigns)

  def helpful(%{on: on}), do: %{on: on}

  @spec serialize(map(), map()) :: map()
  def serialize(reply, %{authors: authors, attachments: attachments}) do
    deleted = reply.deleted_at != nil
    # Removed by a moderator reads as a marker, like a deleted one
    hidden = deleted or reply.status == :removed

    reply
    |> Map.take(@fields)
    |> Map.merge(%{
      author: if(hidden, do: nil, else: UserJSON.summary(authors[reply.author_id])),
      body: if(hidden, do: nil, else: reply.body),
      deleted: deleted,
      attachments: if(hidden, do: [], else: Map.get(attachments, reply.id, []))
    })
  end
end
