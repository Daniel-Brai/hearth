defmodule Hearth.Forum.Reply do
  use Hearth.Repo.Schema, prefix: "forum", soft_delete?: true
  use Flop.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Forum.Post

  @changeable [:body, :attachment_ids]

  @flop_options [
    filterable: [:post_id, :parent_reply_id],
    sortable: ~w[helpful_count inserted_at id]a,
    default_order: %{order_by: [:inserted_at, :id], order_directions: [:asc, :asc]},
    default_limit: 20
  ]

  schema "replies" do
    field :post_id, Ecto.UUID
    field :author_id, Ecto.UUID
    field :parent_reply_id, Ecto.UUID
    field :root_reply_id, Ecto.UUID
    field :body, :string, default: ""
    field :depth, :integer, default: 0
    field :path, {:array, Ecto.UUID}, default: []
    field :child_count, :integer, default: 0
    field :descendant_count, :integer, default: 0
    field :recent_repliers, {:array, Ecto.UUID}, default: []
    field :helpful_count, :integer, default: 0
    field :status, Ecto.Enum, values: ~w[published pending removed]a, default: :published
    field :edited_at, :utc_datetime_usec
    field :attachment_ids, {:array, Ecto.UUID}, virtual: true
    field :deleted_at, :utc_datetime_usec

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          post_id: T.id(),
          author_id: nil | T.id(),
          parent_reply_id: nil | T.id(),
          root_reply_id: nil | T.id(),
          body: String.t(),
          depth: integer(),
          path: [T.id()],
          child_count: integer(),
          descendant_count: integer(),
          recent_repliers: [T.id()],
          helpful_count: integer(),
          status: :published | :pending | :removed,
          edited_at: nil | DateTime.t(),
          deleted_at: nil | DateTime.t(),
          attachment_ids: nil | [T.id()]
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = reply, %{} = params) do
    reply
    |> cast(params, @changeable)
    |> validate_body()
    |> validate_length(:body, max: 10_000)
    |> check_constraint(:parent_reply_id,
      name: :parent_same_post,
      message: "must be a reply on the same post"
    )
  end

  @spec edit(t(), map()) :: {:ok, t()} | {:error, Changeset.t()}
  def edit(%__MODULE__{} = reply, %{} = params) do
    with {:ok, reply} <- __MODULE__.update(reply, params) do
      reply
      |> change(edited_at: DateTime.utc_now())
      |> Repo.update()
    end
  end

  @spec count_helpful(T.id(), integer()) :: :ok
  def count_helpful(id, by) do
    __MODULE__
    |> where(id: ^id)
    |> Repo.update_all(inc: [helpful_count: by])

    :ok
  end

  # Text may be left out when files are attached
  defp validate_body(changeset) do
    case get_field(changeset, :attachment_ids) do
      [_file | _rest] -> put_change(changeset, :body, get_field(changeset, :body) || "")
      _none -> validate_required(changeset, [:body])
    end
  end

  # :all sees pending items too and a user id sees their own
  @type viewer :: nil | :all | T.id()

  # visible_to hides items held for review from everyone but their author
  defp query_from(opts, base) do
    {viewer, opts} = Keyword.pop(opts, :visible_to, :all)
    {community_ids, filters} = Keyword.pop(opts, :in_communities)

    query = super(filters, base)

    query
    |> visible_to(viewer)
    |> in_communities(community_ids)
  end

  defp in_communities(query, nil), do: query

  defp in_communities(query, community_ids) do
    join(query, :inner, [x], p in Post,
      on: p.id == x.post_id and p.community_id in ^community_ids,
      on: p.status == :published and is_nil(p.deleted_at)
    )
  end

  @spec count_answers_by(T.id(), [T.id()]) :: non_neg_integer()
  def count_answers_by(author_id, community_ids) do
    query =
      from r in __MODULE__,
        join: p in Post,
        on: p.answer_reply_id == r.id,
        where: r.author_id == ^author_id and r.status == :published and is_nil(r.deleted_at),
        where: p.community_id in ^community_ids,
        where: p.status == :published and is_nil(p.deleted_at)

    Repo.aggregate(query, :count)
  end

  defp visible_to(query, :all), do: query
  defp visible_to(query, nil), do: where(query, [x], x.status != :pending)

  defp visible_to(query, user_id),
    do: where(query, [x], x.status != :pending or x.author_id == ^user_id)

  @spec put_status(t(), :published | :pending | :removed) :: {:ok, t()} | {:error, Changeset.t()}
  def put_status(%__MODULE__{} = item, status) do
    item
    |> change(status: status)
    |> Repo.update()
  end
end
