defmodule Hearth.Forum.PostRead do
  use Hearth.Repo.Schema, prefix: "forum", primary_key: false

  alias Hearth.Common.T
  alias Hearth.Forum.Post

  schema "post_reads" do
    field :user_id, Ecto.UUID, primary_key: true
    field :post_id, Ecto.UUID, primary_key: true
    field :last_seen_at, :utc_datetime_usec
    field :seen_reply_count, :integer, default: 0
  end

  @type t :: %__MODULE__{
          user_id: T.id(),
          post_id: T.id(),
          last_seen_at: DateTime.t(),
          seen_reply_count: integer()
        }

  @spec seen(T.id(), [T.id()]) :: MapSet.t(T.id())
  def seen(user_id, post_ids) when is_list(post_ids) do
    query =
      from r in __MODULE__,
        where: r.user_id == ^user_id and r.post_id in ^post_ids,
        select: r.post_id

    query |> Repo.all() |> MapSet.new()
  end

  # One statement however many posts, each read up to its replies so far
  @spec mark_all(T.id(), [T.id()]) :: :ok
  def mark_all(user_id, community_ids) when is_list(community_ids) do
    now = DateTime.utc_now()

    posts =
      from p in Post,
        where: p.community_id in ^community_ids and p.status == :published,
        where: is_nil(p.deleted_at),
        select: %{
          user_id: type(^user_id, Ecto.UUID),
          post_id: p.id,
          seen_reply_count: p.reply_count,
          last_seen_at: type(^now, :utc_datetime_usec)
        }

    {_count, _rows} =
      Repo.insert_all(__MODULE__, posts,
        on_conflict: {:replace, [:seen_reply_count, :last_seen_at]},
        conflict_target: [:user_id, :post_id]
      )

    :ok
  end
end
