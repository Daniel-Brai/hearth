defmodule Hearth.Voice.Session do
  use Hearth.Repo.Schema, prefix: "voice"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Voice.Participant

  @fields ~w[mode topic event_id post_id]a
  @modes [:stage, :open]

  schema "sessions" do
    field :room_id, Ecto.UUID
    field :community_id, Ecto.UUID
    field :host_id, Ecto.UUID
    field :event_id, Ecto.UUID
    field :post_id, Ecto.UUID
    field :mode, Ecto.Enum, values: @modes, default: :open
    field :topic, :string
    field :node, :string
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :peak_participants, :integer, default: 0
    field :restarts, :integer, default: 0

    has_many :participants, Participant

    timestamps()
  end

  @type mode :: :stage | :open
  @type t :: %__MODULE__{
          id: T.id(),
          room_id: T.id(),
          community_id: T.id(),
          host_id: nil | T.id(),
          event_id: nil | T.id(),
          post_id: nil | T.id(),
          mode: mode(),
          topic: nil | String.t(),
          node: nil | String.t(),
          started_at: DateTime.t(),
          ended_at: nil | DateTime.t(),
          peak_participants: integer(),
          restarts: integer()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = session, %{} = params) do
    session
    |> cast(params, @fields)
    |> validate_required([:mode])
    |> validate_length(:topic, max: 200)
    |> put_change(:started_at, DateTime.utc_now())
    |> unique_constraint(:room_id,
      name: :sessions_one_live_per_room,
      message: "already has a live session"
    )
  end

  @spec live_in(T.id()) :: nil | t()
  def live_in(room_id), do: get(room_id: room_id, ended_at: nil)

  @spec live_on_posts([T.id()]) :: [t()]
  def live_on_posts(post_ids) do
    __MODULE__
    |> where([s], s.post_id in ^post_ids and is_nil(s.ended_at))
    |> Repo.all()
  end

  @spec live_in_rooms([T.id()]) :: [t()]
  def live_in_rooms(room_ids) do
    __MODULE__
    |> where([s], s.room_id in ^room_ids and is_nil(s.ended_at))
    |> Repo.all()
  end

  @spec live() :: [t()]
  def live, do: all(ended_at: nil)

  @spec finish(t()) :: {:ok, t()}
  def finish(%__MODULE__{ended_at: nil, id: id} = session) do
    ended_at = DateTime.utc_now()

    {count, _rows} =
      __MODULE__
      |> where([s], s.id == ^id and is_nil(s.ended_at))
      |> Repo.update_all(set: [ended_at: ended_at, updated_at: ended_at])

    case count do
      1 -> {:ok, %{session | ended_at: ended_at}}
      0 -> {:ok, get(id: id)}
    end
  end

  def finish(%__MODULE__{} = session), do: {:ok, session}

  @spec count_restart(T.id()) :: non_neg_integer()
  def count_restart(id) do
    {1, [restarts]} =
      __MODULE__
      |> where([s], s.id == ^id)
      |> select([s], s.restarts)
      |> Repo.update_all(inc: [restarts: 1])

    restarts
  end

  @spec note_size(T.id(), non_neg_integer()) :: :ok
  def note_size(id, size) do
    __MODULE__
    |> where([s], s.id == ^id and s.peak_participants < ^size)
    |> Repo.update_all(set: [peak_participants: size])

    :ok
  end
end
