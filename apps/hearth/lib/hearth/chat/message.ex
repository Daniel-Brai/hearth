defmodule Hearth.Chat.Message do
  use Hearth.Repo.Schema, prefix: "chat", soft_delete?: true
  use Flop.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Chat.ConversationMember
  alias Hearth.Chat.RoomRead
  alias Hearth.Common.T

  @changeable [:body, :attachment_ids]

  @flop_options [
    filterable: ~w[room_id conversation_id reply_to_id]a,
    sortable: [:inserted_at, :id],
    default_order: %{order_by: [:inserted_at, :id], order_directions: [:desc, :desc]},
    default_limit: 50
  ]

  schema "messages" do
    field :room_id, Ecto.UUID
    field :conversation_id, Ecto.UUID
    field :author_id, Ecto.UUID
    field :reply_to_id, Ecto.UUID
    field :thread_root_id, Ecto.UUID
    # Encrypted at rest
    field :body, Hearth.Vault.Binary, default: ""
    field :depth, :integer, default: 0
    field :path, {:array, Ecto.UUID}, default: []
    field :child_count, :integer, default: 0
    field :descendant_count, :integer, default: 0
    field :recent_repliers, {:array, Ecto.UUID}, default: []
    field :status, Ecto.Enum, values: ~w[published pending removed]a, default: :published
    field :kind, Ecto.Enum, values: [:text, :promoted], default: :text
    field :post_id, Ecto.UUID
    field :edited_at, :utc_datetime_usec
    field :preview_hidden_at, :utc_datetime_usec
    field :attachment_ids, {:array, Ecto.UUID}, virtual: true
    field :deleted_at, :utc_datetime_usec

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          room_id: nil | T.id(),
          conversation_id: nil | T.id(),
          author_id: nil | T.id(),
          reply_to_id: nil | T.id(),
          thread_root_id: nil | T.id(),
          body: String.t(),
          depth: integer(),
          path: [T.id()],
          child_count: integer(),
          descendant_count: integer(),
          recent_repliers: [T.id()],
          status: :published | :pending | :removed,
          kind: :text | :promoted,
          post_id: nil | T.id(),
          edited_at: nil | DateTime.t(),
          preview_hidden_at: nil | DateTime.t(),
          deleted_at: nil | DateTime.t(),
          attachment_ids: nil | [T.id()]
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = message, %{} = params) do
    message
    |> cast(params, @changeable)
    |> validate_body()
    |> validate_length(:body, max: 4_000)
    |> check_constraint(:reply_to_id,
      name: :parent_same_place,
      message: "must be a message in the same place"
    )
  end

  @spec edit(t(), map()) :: {:ok, t()} | {:error, Changeset.t()}
  def edit(%__MODULE__{} = message, %{} = params) do
    with {:ok, message} <- __MODULE__.update(message, params) do
      message
      |> change(edited_at: DateTime.utc_now())
      |> Repo.update()
    end
  end

  # Text may be left out when files are attached
  defp validate_body(changeset) do
    case get_field(changeset, :attachment_ids) do
      [_file | _rest] -> put_change(changeset, :body, get_field(changeset, :body) || "")
      _none -> validate_required(changeset, [:body])
    end
  end

  @type viewer :: nil | :all | T.id()

  # visible_to hides held items from all but their author unless the viewer may see them all
  defp query_from(opts, base) do
    {viewer, filters} = Keyword.pop(opts, :visible_to, :all)

    query = super(filters, base)

    visible_to(query, viewer)
  end

  defp visible_to(query, :all), do: query
  defp visible_to(query, nil), do: where(query, [x], x.status != :pending)

  defp visible_to(query, user_id),
    do: where(query, [x], x.status != :pending or x.author_id == ^user_id)

  @spec promotable(T.id(), [T.id()]) :: [t()]
  def promotable(room_id, ids) do
    __MODULE__
    |> where(room_id: ^room_id, kind: :text, status: :published)
    |> where([m], m.id in ^ids and is_nil(m.deleted_at) and not is_nil(m.author_id))
    |> order_by(asc: :inserted_at, asc: :id)
    |> Repo.all()
  end

  @spec put_status(t(), :published | :pending | :removed) :: {:ok, t()} | {:error, Changeset.t()}
  def put_status(%__MODULE__{} = item, status) do
    item
    |> change(status: status)
    |> Repo.update()
  end

  @spec hide_preview(t(), boolean()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def hide_preview(%__MODULE__{} = record, hidden?) do
    record
    |> Ecto.Changeset.change(preview_hidden_at: if(hidden?, do: DateTime.utc_now()))
    |> Repo.update()
  end

  # Published messages from others after the read marker, or since joining where there is none yet
  @spec unread_in_rooms(T.id(), %{T.id() => DateTime.t()}) :: %{T.id() => pos_integer()}
  def unread_in_rooms(_user_id, since) when map_size(since) == 0, do: %{}

  def unread_in_rooms(user_id, since) do
    {room_ids, times} =
      since |> Enum.map(fn {id, at} -> {Ecto.UUID.dump!(id), at} end) |> Enum.unzip()

    query =
      from m in __MODULE__,
        join:
          s in fragment(
            "SELECT * FROM unnest(?::uuid[], ?::timestamptz[]) AS s(room_id, since)",
            ^room_ids,
            ^times
          ),
        on: s.room_id == m.room_id,
        left_join: r in RoomRead,
        on: r.room_id == m.room_id and r.user_id == ^user_id,
        where: m.author_id != ^user_id and m.status == :published and is_nil(m.deleted_at),
        where:
          (not is_nil(r.last_read_message_id) and m.id > r.last_read_message_id) or
            (is_nil(r.last_read_message_id) and m.inserted_at > s.since),
        group_by: m.room_id,
        select: {m.room_id, count()}

    query |> Repo.all() |> Map.new()
  end

  @spec unread_in_conversations(T.id()) :: %{T.id() => pos_integer()}
  def unread_in_conversations(user_id) do
    query =
      from m in __MODULE__,
        join: c in ConversationMember,
        on: c.conversation_id == m.conversation_id and c.user_id == ^user_id,
        where: m.author_id != ^user_id and m.status == :published and is_nil(m.deleted_at),
        where: is_nil(c.last_read_message_id) or m.id > c.last_read_message_id,
        group_by: m.conversation_id,
        select: {m.conversation_id, count()}

    query |> Repo.all() |> Map.new()
  end
end
