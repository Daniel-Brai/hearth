defmodule Hearth.Moderation.Screening do
  use Hearth.Repo.Schema, prefix: "moderation"

  import Ecto.Query

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Moderation.Verdict
  alias Hearth.Repo

  schema "screenings" do
    field :community_id, Ecto.UUID
    field :subject_type, Ecto.Enum, values: ~w[post reply message]a
    field :subject_id, Ecto.UUID
    field :screener, :string
    field :verdict, Ecto.Enum, values: Verdict.verdicts()
    field :score, :float
    field :categories, {:array, :string}, default: []
    field :held, :boolean, default: false
    field :outcome, Ecto.Enum, values: [:kept, :removed]
    field :duration_ms, :integer

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          community_id: nil | T.id(),
          subject_type: :post | :reply | :message,
          subject_id: T.id(),
          screener: String.t(),
          verdict: :safe | :controversial | :unsafe,
          score: float(),
          categories: [String.t()],
          held: boolean(),
          outcome: nil | :kept | :removed,
          duration_ms: integer()
        }

  @type day :: %{
          day: Date.t(),
          screened: non_neg_integer(),
          held: non_neg_integer(),
          kept: non_neg_integer(),
          removed: non_neg_integer()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = screening, %{} = params) do
    screening
    |> Changeset.cast(params, [])
    |> Changeset.validate_required(~w[subject_type subject_id screener verdict score]a)
  end

  @spec record_outcome(atom(), T.id(), :kept | :removed) :: :ok
  def record_outcome(subject_type, subject_id, outcome) do
    newest =
      from(s in __MODULE__,
        where: s.subject_type == ^subject_type and s.subject_id == ^subject_id and s.held,
        order_by: [desc: s.inserted_at],
        limit: 1,
        select: s.id
      )

    query = from(s in __MODULE__, where: s.id in subquery(newest))
    Repo.update_all(query, set: [outcome: outcome, updated_at: DateTime.utc_now()])

    :ok
  end

  @spec daily(pos_integer()) :: [day()]
  def daily(days) do
    since = DateTime.add(DateTime.utc_now(), -days, :day)

    query =
      from(s in __MODULE__,
        where: s.inserted_at >= ^since,
        group_by: fragment("1"),
        order_by: [desc: fragment("1")],
        select: %{
          day: fragment("(? AT TIME ZONE 'UTC')::date", s.inserted_at),
          screened: count(s.id),
          held: filter(count(s.id), s.held),
          kept: filter(count(s.id), s.outcome == :kept),
          removed: filter(count(s.id), s.outcome == :removed)
        }
      )

    Repo.all(query)
  end
end
