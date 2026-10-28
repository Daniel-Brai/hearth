defmodule Hearth.Forum.Post do
  use Hearth.Repo.Schema, prefix: "forum", soft_delete?: true
  use Flop.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Forum.Kind
  alias Hearth.Forum.PostRead
  alias Hearth.Forum.PostTag
  alias Hearth.Forum.Tag

  @fields ~w[title body kind_id attachment_ids]a
  @changeable @fields

  @flop_options [
    filterable: ~w[community_id kind_id status]a,
    sortable: ~w[last_activity_at inserted_at id]a,
    default_order: %{order_by: [:last_activity_at, :id], order_directions: [:desc, :desc]},
    default_limit: 20
  ]

  schema "posts" do
    field :community_id, Ecto.UUID
    field :author_id, Ecto.UUID
    field :title, :string
    field :body, :string, default: ""
    field :status, Ecto.Enum, values: ~w[published pending removed]a, default: :published
    field :pinned_at, :utc_datetime_usec
    field :locked_at, :utc_datetime_usec
    field :preview_hidden_at, :utc_datetime_usec
    field :answer_reply_id, Ecto.UUID
    field :reply_count, :integer, default: 0
    field :helpful_count, :integer, default: 0
    field :last_activity_at, :utc_datetime_usec
    field :edited_at, :utc_datetime_usec
    field :attachment_ids, {:array, Ecto.UUID}, virtual: true
    field :deleted_at, :utc_datetime_usec
    field :source_message_id, Ecto.UUID
    field :source_session_id, Ecto.UUID
    field :source_room_id, Ecto.UUID
    field :source_message_count, :integer
    field :promoted_by_id, Ecto.UUID

    belongs_to :kind, Kind
    many_to_many :tags, Tag, join_through: PostTag, on_replace: :delete

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          community_id: T.id(),
          author_id: nil | T.id(),
          title: String.t(),
          body: String.t(),
          status: :published | :pending | :removed,
          pinned_at: nil | DateTime.t(),
          locked_at: nil | DateTime.t(),
          preview_hidden_at: nil | DateTime.t(),
          answer_reply_id: nil | T.id(),
          reply_count: integer(),
          helpful_count: integer(),
          last_activity_at: DateTime.t(),
          edited_at: nil | DateTime.t(),
          deleted_at: nil | DateTime.t(),
          source_message_id: nil | T.id(),
          source_session_id: nil | T.id(),
          source_room_id: nil | T.id(),
          source_message_count: nil | pos_integer(),
          promoted_by_id: nil | T.id(),
          kind_id: T.id(),
          attachment_ids: nil | [T.id()]
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = post, %{} = params) do
    post
    |> cast(params, @fields)
    |> update_change(:title, &String.trim/1)
    |> validate_required([:title, :kind_id])
    |> validate_length(:title, max: 150)
    |> validate_length(:body, max: 40_000)
    |> put_activity()
  end

  defp put_activity(%Changeset{data: %{last_activity_at: nil}} = changeset) do
    put_change(changeset, :last_activity_at, DateTime.utc_now())
  end

  defp put_activity(changeset), do: changeset

  @spec edit(t(), map()) :: {:ok, t()} | {:error, Changeset.t()}
  def edit(%__MODULE__{} = post, %{} = params) do
    with {:ok, post} <- __MODULE__.update(post, params) do
      post
      |> change(edited_at: DateTime.utc_now())
      |> Repo.update()
    end
  end

  @spec count_by_author(T.id(), [T.id()]) :: non_neg_integer()
  def count_by_author(author_id, community_ids) do
    __MODULE__
    |> where([p], p.author_id == ^author_id and p.community_id in ^community_ids)
    |> where([p], p.status == :published and is_nil(p.deleted_at))
    |> Repo.aggregate(:count)
  end

  @spec pinned(T.id()) :: [t()]
  def pinned(community_id) do
    __MODULE__
    |> where([p], p.community_id == ^community_id and not is_nil(p.pinned_at))
    |> where([p], is_nil(p.deleted_at))
    |> order_by(desc: :pinned_at)
    |> Repo.all()
  end

  @spec unread_since(T.id(), [T.id()], DateTime.t(), pos_integer()) :: [t()]
  def unread_since(user_id, community_ids, %DateTime{} = since, limit) do
    query =
      from(p in __MODULE__,
        left_join: r in PostRead,
        on: r.post_id == p.id and r.user_id == ^user_id,
        where: p.community_id in ^community_ids and p.author_id != ^user_id,
        where: p.status == :published and is_nil(p.deleted_at),
        where: p.inserted_at >= ^since and is_nil(r.post_id),
        order_by: [desc: p.inserted_at],
        limit: ^limit
      )

    Repo.all(query)
  end

  @spec pin(t(), boolean()) :: {:ok, t()} | {:error, Changeset.t()}
  def pin(%__MODULE__{} = post, pinned?) do
    post
    |> change(pinned_at: if(pinned?, do: DateTime.utc_now()))
    |> Repo.update()
  end

  @spec lock(t(), boolean()) :: {:ok, t()} | {:error, Changeset.t()}
  def lock(%__MODULE__{} = post, locked?) do
    post
    |> change(locked_at: if(locked?, do: DateTime.utc_now()))
    |> Repo.update()
  end

  @spec set_answer(t(), nil | T.id()) :: {:ok, t()} | {:error, Changeset.t()}
  def set_answer(%__MODULE__{} = post, reply_id) do
    post
    |> change(answer_reply_id: reply_id)
    |> Repo.update()
  end

  @spec count_helpful(T.id(), integer()) :: :ok
  def count_helpful(id, by) do
    __MODULE__
    |> where(id: ^id)
    |> Repo.update_all(inc: [helpful_count: by])

    :ok
  end

  # Oldest first so each sitemap file only grows at its end
  @spec sitemap_entries(T.id(), non_neg_integer(), non_neg_integer()) :: [map()]
  def sitemap_entries(community_id, offset, limit) do
    community_id
    |> listed()
    |> order_by(asc: :inserted_at, asc: :id)
    |> offset(^offset)
    |> limit(^limit)
    |> select([p], %{id: p.id, title: p.title, updated_at: p.last_activity_at})
    |> Repo.all()
  end

  @spec sitemap_stats([T.id()]) :: %{T.id() => {non_neg_integer(), DateTime.t()}}
  def sitemap_stats(community_ids) do
    __MODULE__
    |> where([p], p.community_id in ^community_ids)
    |> where([p], p.status == :published and is_nil(p.deleted_at))
    |> group_by([p], p.community_id)
    |> select([p], {p.community_id, {count(p.id), max(p.last_activity_at)}})
    |> Repo.all()
    |> Map.new()
  end

  defp listed(community_id) do
    __MODULE__
    |> where([p], p.community_id == ^community_id)
    |> where([p], p.status == :published and is_nil(p.deleted_at))
  end

  @spec put_status(t(), :published | :pending | :removed) :: {:ok, t()} | {:error, Changeset.t()}
  def put_status(%__MODULE__{} = post, status) do
    post
    |> change(status: status)
    |> Repo.update()
  end

  @spec hide_preview(t(), boolean()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def hide_preview(%__MODULE__{} = record, hidden?) do
    record
    |> Ecto.Changeset.change(preview_hidden_at: if(hidden?, do: DateTime.utc_now()))
    |> Repo.update()
  end
end
