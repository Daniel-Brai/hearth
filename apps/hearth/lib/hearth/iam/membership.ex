defmodule Hearth.IAM.Membership do
  use Hearth.Repo.Schema, prefix: "iam"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.IAM.MembershipRole
  alias Hearth.IAM.Role

  @fields ~w[community_id user_id joined_at]a

  schema "memberships" do
    field :community_id, Ecto.UUID
    field :user_id, Ecto.UUID
    field :joined_at, :utc_datetime_usec
    field :permissions, {:array, :string}, virtual: true, default: []

    many_to_many :roles, Role, join_through: MembershipRole, on_replace: :delete

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          community_id: T.id(),
          user_id: T.id(),
          joined_at: DateTime.t(),
          permissions: [String.t()]
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = membership, %{} = params) do
    membership
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> unique_constraint([:community_id, :user_id], error_key: :user_id)
  end

  @spec create(map(), [Role.t()]) :: {:ok, t()} | {:error, Changeset.t()}
  def create(%{} = params, roles) when is_list(roles) do
    %__MODULE__{}
    |> changeset(params)
    |> put_assoc(:roles, roles)
    |> Repo.insert()
  end

  @spec set_roles(t(), [Role.t()]) :: {:ok, t()} | {:error, Changeset.t()}
  def set_roles(%__MODULE__{} = membership, roles) when is_list(roles) do
    membership
    |> Repo.preload(:roles)
    |> change()
    |> put_assoc(:roles, roles)
    |> Repo.update()
  end

  @spec shared?(T.id(), T.id()) :: boolean()
  def shared?(user_id, other_id) do
    __MODULE__
    |> join(:inner, [m], o in __MODULE__, on: o.community_id == m.community_id)
    |> where([m, o], m.user_id == ^user_id and o.user_id == ^other_id)
    |> Repo.exists?()
  end

  @spec co_members(T.id(), [T.id()]) :: %{T.id() => [T.id()]}
  def co_members(user_id, community_ids) do
    query =
      from(m in __MODULE__,
        where: m.community_id in ^community_ids and m.user_id != ^user_id,
        select: {m.user_id, m.community_id}
      )

    query
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @spec community_ids(T.id()) :: [T.id()]
  @spec role_keys(T.id()) :: %{T.id() => [String.t()]}
  def role_keys(community_id) do
    query =
      from(m in __MODULE__,
        left_join: r in assoc(m, :roles),
        where: m.community_id == ^community_id,
        select: {m.user_id, r.key}
      )

    query
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {user_id, keys} -> {user_id, Enum.reject(keys, &is_nil/1)} end)
  end

  # The Owner role counts as holding every permission
  @spec holders(T.id(), String.t(), String.t()) :: [T.id()]
  def holders(community_id, permission, owner_key) do
    query =
      from(m in __MODULE__,
        join: r in assoc(m, :roles),
        where: m.community_id == ^community_id,
        where: r.key == ^owner_key or ^permission in r.permissions,
        distinct: true,
        select: m.user_id
      )

    Repo.all(query)
  end

  @spec without_roles(T.id()) :: [T.id()]
  def without_roles(community_id) do
    query =
      from(m in __MODULE__,
        left_join: r in assoc(m, :roles),
        where: m.community_id == ^community_id and is_nil(r.id),
        select: m.user_id
      )

    Repo.all(query)
  end

  @spec count(T.id()) :: non_neg_integer()
  def count(community_id) do
    query = from(m in __MODULE__, where: m.community_id == ^community_id)

    Repo.aggregate(query, :count)
  end

  @spec counts([T.id()]) :: %{T.id() => pos_integer()}
  def counts(community_ids) do
    query =
      from(m in __MODULE__,
        where: m.community_id in ^community_ids,
        group_by: m.community_id,
        select: {m.community_id, count(m.id)}
      )

    query |> Repo.all() |> Map.new()
  end

  def community_ids(user_id) do
    query = from(m in __MODULE__, where: m.user_id == ^user_id, select: m.community_id)

    Repo.all(query)
  end

  @spec joined_at(T.id()) :: %{T.id() => DateTime.t()}
  def joined_at(user_id) do
    query =
      from m in __MODULE__, where: m.user_id == ^user_id, select: {m.community_id, m.joined_at}

    query |> Repo.all() |> Map.new()
  end
end
