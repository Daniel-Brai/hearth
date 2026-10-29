defmodule Hearth.Moderation.Item do
  use Hearth.Repo.Schema, prefix: "moderation"
  use Flop.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Moderation.Report

  @fields ~w[reason note score]a
  @sources ~w[automatic report instance]a
  @subjects ~w[post reply message]a
  @statuses ~w[pending kept removed dismissed]a

  @flop_options [
    filterable: ~w[community_id status source]a,
    sortable: [:inserted_at, :id],
    default_order: %{order_by: [:inserted_at, :id], order_directions: [:desc, :desc]},
    default_limit: 20
  ]

  schema "items" do
    field :community_id, Ecto.UUID
    field :room_id, Ecto.UUID
    field :source, Ecto.Enum, values: @sources
    field :subject_type, Ecto.Enum, values: @subjects
    field :subject_id, Ecto.UUID
    field :author_id, Ecto.UUID
    field :reason, :string
    field :note, :string
    field :score, :float
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :report_count, :integer, default: 0
    field :held, :boolean, default: false
    field :reviewed_by_id, Ecto.UUID
    field :reviewed_at, :utc_datetime_usec

    has_many :reports, Report

    timestamps()
  end

  @type source :: :automatic | :report | :instance
  @type subject_type :: :post | :reply | :message
  @type status :: :pending | :kept | :removed | :dismissed
  @type t :: %__MODULE__{
          id: T.id(),
          community_id: nil | T.id(),
          room_id: nil | T.id(),
          source: source(),
          subject_type: subject_type(),
          subject_id: T.id(),
          author_id: T.id(),
          reason: nil | String.t(),
          note: nil | String.t(),
          score: nil | float(),
          status: status(),
          report_count: integer(),
          held: boolean(),
          reviewed_by_id: nil | T.id(),
          reviewed_at: nil | DateTime.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = item, %{} = params) do
    item
    |> cast(params, @fields)
    |> validate_required(~w[source subject_type subject_id author_id]a)
    |> validate_length(:reason, max: 500)
    |> validate_length(:note, max: 1_000)
    |> validate_number(:score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> unique_constraint([:subject_type, :subject_id], name: :items_one_pending_index)
  end

  @spec pending(subject_type(), T.id()) :: nil | t()
  def pending(subject_type, subject_id) do
    get(subject_type: subject_type, subject_id: subject_id, status: :pending)
  end

  @spec last_removal(subject_type(), T.id()) :: nil | t()
  def last_removal(subject_type, subject_id) do
    query =
      from i in __MODULE__,
        where: i.subject_type == ^subject_type and i.subject_id == ^subject_id,
        where: i.status == :removed,
        order_by: [desc: i.reviewed_at],
        limit: 1

    Repo.one(query)
  end

  @spec pending_subjects(subject_type(), [T.id()]) :: [T.id()]
  def pending_subjects(subject_type, subject_ids) when is_list(subject_ids) do
    query =
      from i in __MODULE__,
        where: i.subject_type == ^subject_type and i.subject_id in ^subject_ids,
        where: i.status == :pending,
        distinct: true,
        select: i.subject_id

    Repo.all(query)
  end

  # Only writes if the item is still at the status it was read with so two moderators deciding at once can't both win
  @spec decide(t(), status(), nil | T.id()) :: {:ok, t()} | {:error, :stale}
  def decide(%__MODULE__{} = item, status, reviewed_by_id) do
    reviewed_at = if status == :pending, do: nil, else: DateTime.utc_now()
    reviewer = if status == :pending, do: nil, else: reviewed_by_id
    now = DateTime.utc_now()

    query = where(__MODULE__, id: ^item.id, status: ^item.status)

    changes = [
      status: status,
      reviewed_by_id: reviewer,
      reviewed_at: reviewed_at,
      updated_at: now
    ]

    case Repo.update_all(query, set: changes) do
      {1, _rows} ->
        {:ok, %{item | status: status, reviewed_by_id: reviewer, reviewed_at: reviewed_at}}

      {0, _rows} ->
        {:error, :stale}
    end
  end

  @spec hold(t()) :: {:ok, t()}
  def hold(%__MODULE__{held: true} = item), do: {:ok, item}

  def hold(%__MODULE__{id: id} = item) do
    {1, _rows} =
      __MODULE__
      |> where(id: ^id)
      |> Repo.update_all(set: [held: true, updated_at: DateTime.utc_now()])

    {:ok, %{item | held: true}}
  end

  @spec count_report(t()) :: :ok
  def count_report(%__MODULE__{id: id}) do
    {1, _rows} =
      __MODULE__
      |> where(id: ^id)
      |> Repo.update_all(inc: [report_count: 1])

    :ok
  end

  @spec pending_counts([T.id()], [T.id()]) :: %{T.id() => non_neg_integer()}
  def pending_counts(community_ids, hidden_room_ids) when is_list(community_ids) do
    query =
      from(i in __MODULE__,
        where: i.community_id in ^community_ids and i.status == :pending,
        group_by: i.community_id,
        select: {i.community_id, count(i.id)}
      )

    query
    |> outside_rooms(hidden_room_ids)
    |> Repo.all()
    |> Map.new()
  end

  defp query_from(opts, query) do
    {hidden_room_ids, opts} = Keyword.pop(opts, :outside_rooms, [])
    super(opts, outside_rooms(query, hidden_room_ids))
  end

  defp outside_rooms(query, []), do: query

  defp outside_rooms(query, room_ids),
    do: where(query, [i], is_nil(i.room_id) or i.room_id not in ^room_ids)
end
