defmodule Hearth.Communities.Room do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Communities.Community

  @levels ~w[full reports none]a
  # The moderation level changes through Hearth.Moderation.set_level/3, which logs it
  @fields ~w[type name topic position settings]a
  @changeable @fields -- [:type]

  schema "rooms" do
    field :type, Ecto.Enum, values: [:text, :voice], default: :text
    field :slug, :string
    field :name, :string
    field :topic, :string
    field :position, :integer, default: 0
    field :moderation, Ecto.Enum, values: @levels
    field :settings, :map, default: %{}
    field :archived_at, :utc_datetime_usec

    belongs_to :community, Community

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          type: :text | :voice,
          slug: String.t(),
          name: String.t(),
          topic: nil | String.t(),
          position: integer(),
          moderation: nil | :full | :reports | :none,
          settings: map(),
          archived_at: nil | DateTime.t(),
          community_id: T.id()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = room, %{} = params) do
    room
    |> cast(params, @fields)
    |> validate_required([:name])
    |> validate_length(:name, max: 40)
    |> validate_length(:topic, max: 200)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> put_slug()
    |> validate_required([:slug])
    |> unique_constraint([:community_id, :slug], error_key: :name)
  end

  defp put_slug(%Changeset{data: %{slug: nil}} = changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, Common.slugify(name))
    end
  end

  defp put_slug(changeset), do: changeset

  @spec for_community(T.id()) :: [t()]
  def for_community(community_id) do
    __MODULE__
    |> where([r], r.community_id == ^community_id and is_nil(r.archived_at))
    |> order_by(:position)
    |> Repo.all()
  end

  @spec archived(T.id()) :: [t()]
  def archived(community_id) do
    __MODULE__
    |> where([r], r.community_id == ^community_id and not is_nil(r.archived_at))
    |> order_by(desc: :archived_at)
    |> Repo.all()
  end

  @spec archive(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def archive(%__MODULE__{} = room) do
    room
    |> change(archived_at: DateTime.utc_now())
    |> Repo.update()
  end

  @spec restore(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def restore(%__MODULE__{} = room) do
    room
    |> change(archived_at: nil)
    |> Repo.update()
  end

  @spec put_moderation(t(), nil | Hearth.Communities.Community.level()) ::
          {:ok, t()} | {:error, Changeset.t()}
  def put_moderation(%__MODULE__{} = room, level) do
    room
    |> change(moderation: level)
    |> Repo.update()
  end
end
