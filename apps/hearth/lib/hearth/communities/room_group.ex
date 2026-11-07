defmodule Hearth.Communities.RoomGroup do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @most 50

  @changeable [:name]

  schema "room_groups" do
    field :community_id, Ecto.UUID
    field :name, :string
    field :position, :integer, default: 0

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          community_id: T.id(),
          name: String.t(),
          position: integer()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = group, %{} = params) do
    group
    |> cast(params, @changeable)
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 40)
  end

  @spec add(T.id(), map()) :: {:ok, t()} | {:error, :too_many_groups | Changeset.t()}
  def add(community_id, %{} = params) do
    Repo.transact(fn ->
      count = community_id |> in_community() |> lock("FOR UPDATE") |> Repo.all() |> length()

      case count < @most do
        true -> insert(%__MODULE__{community_id: community_id, position: count}, params)
        false -> {:error, :too_many_groups}
      end
    end)
  end

  @spec for_communities([T.id()]) :: [t()]
  def for_communities(community_ids) do
    __MODULE__
    |> where([g], g.community_id in ^community_ids)
    |> order_by([:position, :inserted_at])
    |> Repo.all()
  end

  @spec ids_in(T.id()) :: [T.id()]
  def ids_in(community_id), do: community_id |> in_community() |> select([g], g.id) |> Repo.all()

  @spec put_position(T.id(), non_neg_integer()) :: :ok
  def put_position(id, position) do
    {1, nil} = __MODULE__ |> where(id: ^id) |> Repo.update_all(set: [position: position])

    :ok
  end

  defp in_community(community_id), do: where(__MODULE__, community_id: ^community_id)
end
