defmodule Hearth.Moderation.Action do
  use Hearth.Repo.Schema, prefix: "moderation"
  use Flop.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @fields [:reason, :metadata]
  @actions ~w[removed restored kept banned unbanned server_muted server_mute_lifted disconnected
               moved_to_listeners recording_started recording_stopped pinned locked changed]a
  @subjects ~w[post reply message user community room]a

  @flop_options [
    filterable: [:community_id],
    sortable: [:inserted_at, :id],
    default_order: %{order_by: [:inserted_at, :id], order_directions: [:desc, :desc]},
    default_limit: 30
  ]

  schema "actions" do
    field :community_id, Ecto.UUID
    field :actor_id, Ecto.UUID
    field :target_id, Ecto.UUID
    field :action, Ecto.Enum, values: @actions
    field :subject_type, Ecto.Enum, values: @subjects
    field :subject_id, Ecto.UUID
    field :reason, :string
    field :metadata, :map, default: %{}

    timestamps(updated_at: false)
  end

  @type action ::
          :removed
          | :restored
          | :kept
          | :banned
          | :unbanned
          | :server_muted
          | :server_mute_lifted
          | :disconnected
          | :moved_to_listeners
          | :recording_started
          | :recording_stopped
          | :pinned
          | :locked
          | :changed
  @type subject_type :: :post | :reply | :message | :user | :community | :room
  @type t :: %__MODULE__{
          id: T.id(),
          community_id: nil | T.id(),
          actor_id: T.id(),
          target_id: nil | T.id(),
          action: action(),
          subject_type: subject_type(),
          subject_id: T.id(),
          reason: nil | String.t(),
          metadata: map()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = action, %{} = params) do
    action
    |> cast(params, @fields)
    |> validate_required(~w[actor_id action subject_type subject_id]a)
    |> validate_length(:reason, max: 500)
  end
end
