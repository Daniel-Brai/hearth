defmodule Hearth.Forum.Post do
  use Hearth.Repo.Schema, prefix: "forum", soft_delete?: true
  use Flop.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Forum.Bookmark
  alias Hearth.Forum.Kind
  alias Hearth.Forum.PostRead
  alias Hearth.Forum.PostTag
  alias Hearth.Forum.Reply
  alias Hearth.Forum.Tag

  @fields ~w[title body kind_id attachment_ids]a
  @changeable @fields

  @flop_options [
    filterable: ~w[community_id kind_id status]a,
    sortable: ~w[last_activity_at inserted_at bookmarked_at id]a,
    default_order: %{order_by: [:last_activity_at, :id], order_directions: [:desc, :desc]},
    default_limit: 20,
    adapter_opts: [
      join_fields: [
        bookmarked_at: [binding: :bookmark, field: :inserted_at, ecto_type: :utc_datetime_usec]
      ]
    ]
  ]

  schema "posts" do
    field :community_id, Ecto.UUID
    field :author_id, Ecto.UUID
    field :title, :string
    field :body, :string, default: ""
    field :status, Ecto.Enum, values: ~w[published pending removed]a, default: :published
    field :pinned_at, :utc_datetime_usec
    field :locked_at, :utc_datetime_usec
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
    # Postgres fills it from the title and body
    field :search, :string, load_in_query: false, writable: :never

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
          search: nil | String.t(),
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

  @type match :: %{
          post: t(),
          tier: 0..2,
          reply_id: nil | T.id(),
          reply_body: nil | String.t()
        }

  # 2 when the title matches, 1 when only the body does and 0 when only a reply does
  defmacrop tier(search, terms) do
    quote do
      fragment(
        "CASE WHEN ts_filter(?, '{a}') @@ to_tsquery('simple', ?) THEN 2 WHEN ? @@ to_tsquery('simple', ?) THEN 1 ELSE 0 END",
        unquote(search),
        unquote(terms),
        unquote(search),
        unquote(terms)
      )
    end
  end

  # Every word must match as the start of a word in the post or one of its replies
  # Pages go by tier then latest activity and the cursor holds the last row's place in that order
  @spec search([String.t()], [T.id()], keyword()) ::
          {:ok, [match()], nil | String.t()} | {:error, :invalid_cursor}
  def search([], _community_ids, _opts), do: {:ok, [], nil}

  def search(words, community_ids, opts) do
    limit = opts[:limit] || 20
    terms = Enum.map_join(words, " & ", &(&1 <> ":*"))

    with {:ok, position} <- decode_cursor(opts[:after]) do
      matches =
        terms
        |> search_query(community_ids)
        |> after_position(position, terms)
        |> limit(^(limit + 1))
        |> Repo.all()

      {page, rest} = Enum.split(matches, limit)

      {:ok, page, next_cursor(page, rest)}
    end
  end

  defp search_query(terms, community_ids) do
    in_posts =
      from p in __MODULE__,
        where: fragment("? @@ to_tsquery('simple', ?)", p.search, ^terms),
        select: p.id

    in_replies = terms |> matching_replies() |> select([r], r.post_id)

    best_reply =
      terms
      |> matching_replies()
      |> distinct([r], r.post_id)
      |> order_by([r], asc: r.post_id, desc: r.helpful_count, asc: r.id)

    from p in __MODULE__,
      left_join: r in subquery(best_reply),
      on: r.post_id == p.id,
      where: p.id in subquery(union(in_posts, ^in_replies)),
      where: p.community_id in ^community_ids,
      where: p.status == :published and is_nil(p.deleted_at),
      order_by: [desc: tier(p.search, ^terms), desc: p.last_activity_at, desc: p.id],
      select: %{post: p, tier: tier(p.search, ^terms), reply_id: r.id, reply_body: r.body}
  end

  defp after_position(query, nil, _terms), do: query

  defp after_position(query, {tier, at, id}, terms) do
    where(
      query,
      [p],
      fragment(
        "(?, ?, ?) < (?, ?, ?)",
        tier(p.search, ^terms),
        p.last_activity_at,
        p.id,
        ^tier,
        ^at,
        type(^id, Ecto.UUID)
      )
    )
  end

  defp next_cursor(_page, []), do: nil

  defp next_cursor(page, _rest) do
    %{tier: tier, post: post} = List.last(page)
    at = DateTime.to_unix(post.last_activity_at, :microsecond)

    Base.url_encode64("#{tier}|#{at}|#{post.id}", padding: false)
  end

  defp decode_cursor(nil), do: {:ok, nil}

  defp decode_cursor(cursor) do
    with {:ok, raw} <- Base.url_decode64(cursor, padding: false),
         [tier, at, id] <- String.split(raw, "|"),
         {tier, ""} when tier in 0..2 <- Integer.parse(tier),
         {at, ""} <- Integer.parse(at),
         {:ok, at} <- DateTime.from_unix(at, :microsecond),
         {:ok, id} <- Ecto.UUID.cast(id) do
      {:ok, {tier, at, id}}
    else
      _invalid -> {:error, :invalid_cursor}
    end
  end

  # The expression matches the replies_search_index migration so Postgres can use it
  defp matching_replies(terms) do
    from r in Reply,
      where: fragment("to_tsvector('simple', ?) @@ to_tsquery('simple', ?)", r.body, ^terms),
      where: r.status == :published and is_nil(r.deleted_at)
  end

  defp query_from(opts, base) do
    {user_id, filters} = Keyword.pop(opts, :bookmarked_by)

    filters
    |> super(base)
    |> bookmarked_by(user_id)
  end

  defp bookmarked_by(query, nil), do: query

  defp bookmarked_by(query, user_id) do
    join(query, :inner, [p], b in Bookmark,
      as: :bookmark,
      on: b.post_id == p.id and b.user_id == ^user_id
    )
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

  # Deleted posts move too, since a kind can't go while any post points at it
  @spec move_kinds([T.id()], T.id()) :: :ok
  def move_kinds(kind_ids, kind_id) do
    __MODULE__
    |> where([p], p.kind_id in ^kind_ids)
    |> Repo.update_all(set: [kind_id: kind_id])

    :ok
  end

  @spec with_kinds?([T.id()]) :: boolean()
  def with_kinds?(kind_ids) do
    __MODULE__
    |> where([p], p.kind_id in ^kind_ids)
    |> Repo.exists?()
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
end
