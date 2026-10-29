defmodule Hearth.Communities.RoomSettings do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @fields ~w[
    link_previews
    sounds_enabled
    sounds_mode
    sounds_role_ids
    sounds_user_ids
  ]a

  @primary_key false

  embedded_schema do
    field :link_previews, :boolean, default: true
    field :sounds_enabled, :boolean, default: true
    field :sounds_mode, Ecto.Enum, values: ~w[everyone roles people]a, default: :everyone
    field :sounds_role_ids, {:array, Ecto.UUID}, default: []
    field :sounds_user_ids, {:array, Ecto.UUID}, default: []
  end

  @type t :: %__MODULE__{
          link_previews: boolean(),
          sounds_enabled: boolean(),
          sounds_mode: :everyone | :roles | :people,
          sounds_role_ids: [T.id()],
          sounds_user_ids: [T.id()]
        }

  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = settings, %{} = params) do
    settings
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> validate_length(:sounds_role_ids, max: 50)
    |> validate_length(:sounds_user_ids, max: 200)
  end

  @spec sound_allowed?(t(), T.id(), [T.id()]) :: boolean()
  def sound_allowed?(%__MODULE__{sounds_enabled: false}, _user_id, _role_ids), do: false
  def sound_allowed?(%__MODULE__{sounds_mode: :everyone}, _user_id, _role_ids), do: true

  def sound_allowed?(%__MODULE__{sounds_mode: :roles} = settings, _user_id, role_ids),
    do: Enum.any?(role_ids, &(&1 in settings.sounds_role_ids))

  def sound_allowed?(%__MODULE__{sounds_mode: :people} = settings, user_id, _role_ids),
    do: user_id in settings.sounds_user_ids
end
