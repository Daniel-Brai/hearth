defmodule Hearth.Voice.Participant do
  use Hearth.Repo.Schema, prefix: "voice"

  import Ecto.Changeset

  alias Hearth.Common.T
  alias Hearth.Voice.Session

  @roles ~w[host speaker listener]a

  schema "participants" do
    belongs_to :session, Session
    field :user_id, Ecto.UUID
    field :role, Ecto.Enum, values: @roles, default: :listener
    field :joined_at, :utc_datetime_usec
    field :left_at, :utc_datetime_usec
    field :hand_raised_at, :utc_datetime_usec
    field :self_muted, :boolean, default: true
    field :server_muted_at, :utc_datetime_usec
    field :server_muted_by_id, Ecto.UUID

    timestamps()
  end

  @type role :: :host | :speaker | :listener
  @type t :: %__MODULE__{
          id: T.id(),
          session_id: T.id(),
          user_id: T.id(),
          role: role(),
          joined_at: DateTime.t(),
          left_at: nil | DateTime.t(),
          hand_raised_at: nil | DateTime.t(),
          self_muted: boolean(),
          server_muted_at: nil | DateTime.t(),
          server_muted_by_id: nil | T.id()
        }

  @spec count_present(T.id()) :: non_neg_integer()
  def count_present(session_id) do
    __MODULE__
    |> where([p], p.session_id == ^session_id and is_nil(p.left_at))
    |> Repo.aggregate(:count)
  end

  @spec present(T.id()) :: [t()]
  def present(session_id) do
    __MODULE__
    |> where([p], p.session_id == ^session_id and is_nil(p.left_at))
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  # A returning person starts muted with no hand up, and keeps a server mute
  @spec enter(T.id(), T.id(), role()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def enter(session_id, user_id, role) when role in @roles do
    now = DateTime.utc_now()

    %__MODULE__{session_id: session_id, user_id: user_id}
    |> change(role: role, joined_at: now, self_muted: true)
    |> Repo.insert(
      on_conflict: [
        set: [role: role, joined_at: now, left_at: nil, hand_raised_at: nil, self_muted: true]
      ],
      conflict_target: [:session_id, :user_id],
      returning: true
    )
  end

  @spec put(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def put(%__MODULE__{} = participant, %{} = changes) do
    participant
    |> change(changes)
    |> Repo.update()
  end

  @spec leave_all(T.id()) :: :ok
  def leave_all(session_id) do
    now = DateTime.utc_now()

    __MODULE__
    |> where([p], p.session_id == ^session_id and is_nil(p.left_at))
    |> Repo.update_all(set: [left_at: now, updated_at: now])

    :ok
  end
end
