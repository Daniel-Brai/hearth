defmodule Hearth.Forum.HelpfulMark do
  use Hearth.Repo.Schema, prefix: "forum"

  alias Hearth.Common.T
  alias Hearth.Forum.Post
  alias Hearth.Forum.Reply

  schema "helpful_marks" do
    field :user_id, Ecto.UUID
    field :post_id, Ecto.UUID
    field :reply_id, Ecto.UUID

    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{
          id: T.id(),
          user_id: T.id(),
          post_id: nil | T.id(),
          reply_id: nil | T.id()
        }

  @spec count_people_helped(T.id(), [T.id()]) :: non_neg_integer()
  def count_people_helped(author_id, community_ids) do
    on_posts =
      from m in __MODULE__,
        join: p in Post,
        on: p.id == m.post_id,
        where: p.author_id == ^author_id and p.community_id in ^community_ids,
        where: p.status == :published and is_nil(p.deleted_at),
        select: m.user_id

    on_replies =
      from m in __MODULE__,
        join: r in Reply,
        on: r.id == m.reply_id,
        join: p in Post,
        on: p.id == r.post_id,
        where: r.author_id == ^author_id and r.status == :published and is_nil(r.deleted_at),
        where: p.community_id in ^community_ids,
        where: p.status == :published and is_nil(p.deleted_at),
        select: m.user_id

    query = from u in subquery(union(on_posts, ^on_replies)), select: count(u.user_id)

    Repo.one(query)
  end
end
