defmodule Hearth.Notifications.Notification do
  use Hearth.Repo.Schema, prefix: "notifications"
  use Flop.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Repo

  @fields ~w[actor_id community_id kind subject_type subject_id data]a
  @kinds ~w[reply mention dm answer event_scheduled event_reminder live_started invite report
             transcript_ready]a

  @flop_options [
    filterable: [:user_id],
    sortable: [:inserted_at, :id],
    default_order: %{order_by: [:inserted_at, :id], order_directions: [:desc, :desc]},
    default_limit: 30
  ]

  schema "notifications" do
    field :user_id, Ecto.UUID
    field :actor_id, Ecto.UUID
    field :community_id, Ecto.UUID
    field :kind, Ecto.Enum, values: @kinds
    field :subject_type, :string
    field :subject_id, Ecto.UUID
    field :data, :map, default: %{}
    field :read_at, :utc_datetime_usec

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          user_id: T.id(),
          actor_id: nil | T.id(),
          community_id: nil | T.id(),
          kind:
            :reply
            | :mention
            | :dm
            | :answer
            | :event_scheduled
            | :event_reminder
            | :live_started
            | :invite
            | :report
            | :transcript_ready,
          subject_type: String.t(),
          subject_id: T.id(),
          data: map(),
          read_at: nil | DateTime.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = notification, %{} = params) do
    notification
    |> cast(params, @fields)
    |> validate_required(@fields -- ~w[actor_id community_id data]a)
  end

  # Capped so a huge backlog costs no more
  @spec unread_count(T.id(), pos_integer()) :: non_neg_integer()
  def unread_count(user_id, most) do
    __MODULE__
    |> where(user_id: ^user_id)
    |> where([n], is_nil(n.read_at))
    |> limit(^most)
    |> select([n], n.id)
    |> subquery()
    |> Repo.aggregate(:count)
  end

  @spec prune_read(DateTime.t(), pos_integer()) :: non_neg_integer()
  def prune_read(%DateTime{} = before, batch) do
    ids =
      __MODULE__
      |> where([n], not is_nil(n.read_at) and n.read_at < ^before)
      |> limit(^batch)
      |> select([n], n.id)

    {count, _rows} = __MODULE__ |> where([n], n.id in subquery(ids)) |> Repo.delete_all()

    count
  end

  @spec mark_read(T.id(), nil | T.id()) :: non_neg_integer()
  def mark_read(user_id, id) do
    {count, _rows} =
      __MODULE__
      |> where(user_id: ^user_id)
      |> where([n], is_nil(n.read_at))
      |> only(id)
      |> Repo.update_all(set: [read_at: DateTime.utc_now()])

    count
  end

  defp only(query, nil), do: query
  defp only(query, id), do: where(query, id: ^id)
end
