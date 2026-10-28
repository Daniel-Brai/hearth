defmodule Hearth.Moderation.Report do
  use Hearth.Repo.Schema, prefix: "moderation"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Moderation.Item

  @fields [:reason, :note]
  @reasons ~w[spam harassment hate sexual violence off_topic other]a

  schema "reports" do
    field :reporter_id, Ecto.UUID
    field :reason, Ecto.Enum, values: @reasons
    field :note, :string

    belongs_to :item, Item

    timestamps(updated_at: false)
  end

  @type reason :: :spam | :harassment | :hate | :sexual | :violence | :off_topic | :other
  @type t :: %__MODULE__{
          id: T.id(),
          reporter_id: T.id(),
          reason: reason(),
          note: nil | String.t(),
          item_id: T.id()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = report, %{} = params) do
    report
    |> cast(params, @fields)
    |> update_change(:note, &String.trim/1)
    |> validate_required(~w[reason item_id reporter_id]a)
    |> validate_length(:note, max: 1_000)
    |> unique_constraint([:item_id, :reporter_id],
      error_key: :item_id,
      message: "already reported"
    )
  end

  @spec exists_for?(Item.t(), T.id()) :: boolean()
  def exists_for?(%Item{id: item_id}, reporter_id),
    do: exists?(item_id: item_id, reporter_id: reporter_id)

  @spec open_subjects(T.id(), Hearth.Moderation.Subject.type(), [T.id()]) :: [T.id()]
  def open_subjects(reporter_id, subject_type, subject_ids) when is_list(subject_ids) do
    query =
      from r in __MODULE__,
        join: i in assoc(r, :item),
        where: r.reporter_id == ^reporter_id,
        where: i.subject_type == ^subject_type and i.subject_id in ^subject_ids,
        where: i.status == :pending,
        select: i.subject_id

    Repo.all(query)
  end

  @spec for_items([T.id()]) :: %{T.id() => [t()]}
  def for_items(item_ids) when is_list(item_ids) do
    __MODULE__
    |> where([r], r.item_id in ^item_ids)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
    |> Enum.group_by(& &1.item_id)
  end
end
