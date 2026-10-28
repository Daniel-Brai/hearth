defmodule Hearth.Communities.Ban do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Communities.Community

  @fields [:reason, :expires_at]

  schema "bans" do
    field :user_id, Ecto.UUID
    field :banned_by_id, Ecto.UUID
    field :lifted_by_id, Ecto.UUID
    field :reason, :string
    field :expires_at, :utc_datetime_usec
    field :lifted_at, :utc_datetime_usec

    belongs_to :community, Community

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          user_id: T.id(),
          banned_by_id: nil | T.id(),
          lifted_by_id: nil | T.id(),
          reason: nil | String.t(),
          expires_at: nil | DateTime.t(),
          lifted_at: nil | DateTime.t(),
          community_id: T.id()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = ban, %{} = params) do
    ban
    |> cast(params, @fields)
    |> validate_length(:reason, max: 500)
    |> validate_change(:expires_at, &in_future/2)
    |> unique_constraint([:community_id, :user_id],
      name: :bans_one_active_index,
      error_key: :user_id,
      message: "is already banned"
    )
  end

  @spec lift_changeset(struct(), T.id()) :: Changeset.t()
  def lift_changeset(%__MODULE__{} = ban, lifted_by_id) do
    change(ban, lifted_at: DateTime.utc_now(), lifted_by_id: lifted_by_id)
  end

  defp in_future(:expires_at, expires_at) do
    case DateTime.after?(expires_at, DateTime.utc_now()) do
      true -> []
      false -> [expires_at: "must be in the future"]
    end
  end

  @spec lift(t(), T.id()) :: {:ok, t()} | {:error, Changeset.t()}
  def lift(%__MODULE__{} = ban, lifted_by_id) do
    ban
    |> lift_changeset(lifted_by_id)
    |> Repo.update()
  end

  @spec in_force(T.id()) :: [t()]
  def in_force(community_id) do
    now = DateTime.utc_now()

    __MODULE__
    |> where([b], b.community_id == ^community_id and is_nil(b.lifted_at))
    |> where([b], is_nil(b.expires_at) or b.expires_at > ^now)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  # Lifts a ban that ran out so a new ban on the same person can be recorded
  @spec close_expired(T.id(), T.id()) :: :ok
  def close_expired(community_id, user_id) do
    now = DateTime.utc_now()

    query =
      where(
        __MODULE__,
        [b],
        b.community_id == ^community_id and b.user_id == ^user_id and is_nil(b.lifted_at) and
          b.expires_at <= ^now
      )

    {_count, _rows} = Repo.update_all(query, set: [lifted_at: now])
    :ok
  end

  @spec active?(T.id(), T.id()) :: boolean()
  def active?(community_id, user_id) do
    now = DateTime.utc_now()

    __MODULE__
    |> where([b], b.community_id == ^community_id and b.user_id == ^user_id)
    |> where([b], is_nil(b.lifted_at) and (is_nil(b.expires_at) or b.expires_at > ^now))
    |> Repo.exists?()
  end
end
