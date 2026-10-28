defmodule Hearth.IAM.Role do
  use Hearth.Repo.Schema, prefix: "iam"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.IAM.Spec

  @fields ~w[community_id key name color position is_default is_system permissions]a
  @changeable ~w[name color position permissions]a

  schema "roles" do
    field :community_id, Ecto.UUID
    field :key, :string
    field :name, :string
    field :color, :string
    field :position, :integer, default: 0
    field :is_default, :boolean, default: false
    field :is_system, :boolean, default: false
    field :permissions, {:array, :string}, default: []

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          community_id: T.id(),
          key: String.t(),
          name: String.t(),
          color: nil | String.t(),
          position: integer(),
          is_default: boolean(),
          is_system: boolean(),
          permissions: [String.t()]
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = role, %{} = params) do
    role
    |> cast(params, @fields)
    |> update_change(:permissions, &Enum.uniq/1)
    |> validate_required(@fields -- ~w[color position is_default is_system permissions]a)
    |> validate_length(:key, max: 30)
    |> validate_length(:name, max: 30)
    |> validate_change(:key, &slug/2)
    |> validate_change(:color, &hex_color/2)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_subset(:permissions, Spec.permissions(:community))
    |> unique_constraint([:community_id, :key], error_key: :key)
    |> unique_constraint(:is_default, name: :roles_one_default_index)
  end

  @spec for_community(T.id()) :: [t()]
  def for_community(community_id) do
    __MODULE__
    |> where(community_id: ^community_id)
    |> order_by(:position)
    |> Repo.all()
  end

  @spec with_keys(T.id(), [String.t()]) :: [t()]
  def with_keys(community_id, keys) when is_list(keys) do
    __MODULE__
    |> where([r], r.community_id == ^community_id and r.key in ^keys)
    |> Repo.all()
  end

  defp hex_color(:color, "#" <> hex) when byte_size(hex) == 6 do
    case Base.decode16(hex, case: :mixed) do
      {:ok, _bytes} -> []
      :error -> [color: "must be a hex color"]
    end
  end

  defp hex_color(:color, _color), do: [color: "must be a hex color"]

  defp slug(:key, key) do
    case Common.slugify(key) == key do
      true -> []
      false -> [key: "must be lowercase letters, digits and dashes"]
    end
  end
end
