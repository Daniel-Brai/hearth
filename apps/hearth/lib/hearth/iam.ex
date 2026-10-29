defmodule Hearth.IAM do
  use Boundary,
    deps: [Hearth.Accounts, Hearth.Common, Hearth.Repo],
    exports: [Membership, Object, Role]

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Common.T
  alias Hearth.IAM.Command.CreateDefaultRoles
  alias Hearth.IAM.Membership
  alias Hearth.IAM.Object
  alias Hearth.IAM.Role
  alias Hearth.IAM.Spec

  @owner "owner"

  @spec cache_specs() :: :ok
  def cache_specs, do: Spec.cache()

  @spec permissions() :: [String.t()]
  def permissions do
    Enum.sort(Spec.permissions(:community) ++ Spec.permissions(:instance))
  end

  @spec create_default_roles(T.id()) :: {:ok, [Role.t()]} | {:error, Changeset.t()}
  def create_default_roles(community_id) when is_binary(community_id) do
    CreateDefaultRoles.execute(community_id)
  end

  @spec list_roles(T.id()) :: [Role.t()]
  def list_roles(community_id) when is_binary(community_id) do
    Role.for_community(community_id)
  end

  @spec create_role(T.id(), map()) :: {:ok, Role.t()} | {:error, Changeset.t()}
  def create_role(community_id, %{} = params) when is_binary(community_id) do
    Role.insert(%Role{community_id: community_id}, params)
  end

  @spec update_role(Role.t(), map()) :: {:ok, Role.t()} | {:error, Changeset.t()}
  def update_role(%Role{} = role, %{} = params), do: Role.update(role, params)

  @spec get_role(T.id()) :: {:ok, Role.t()} | {:error, :not_found}
  def get_role(id) when is_binary(id) do
    case Role.get(id: id) do
      nil -> {:error, :not_found}
      %Role{} = role -> {:ok, role}
    end
  end

  @spec delete_role(Role.t()) :: {:ok, Role.t()} | {:error, :system_role | :default_role}
  def delete_role(%Role{is_system: true}), do: {:error, :system_role}
  def delete_role(%Role{is_default: true}), do: {:error, :default_role}
  def delete_role(%Role{} = role), do: Role.delete(role)

  # With no keys, the member acts as the community's default role
  @spec join(User.t(), T.id(), [String.t()]) :: {:ok, Membership.t()} | {:error, Changeset.t()}
  def join(%User{id: user_id}, community_id, keys \\ []) when is_list(keys) do
    params = %{community_id: community_id, user_id: user_id, joined_at: DateTime.utc_now()}

    with {:ok, membership} <- Membership.create(params, Role.with_keys(community_id, keys)) do
      {:ok, with_permissions(membership)}
    end
  end

  @spec leave(User.t(), T.id()) :: :ok
  def leave(%User{id: user_id}, community_id) do
    with %Membership{} = membership <-
           Membership.get(user_id: user_id, community_id: community_id) do
      Membership.delete(membership)
    end

    :ok
  end

  @spec community_ids(User.t()) :: [T.id()]
  def community_ids(%User{id: user_id}), do: Membership.community_ids(user_id)

  @spec joined_at(User.t()) :: %{T.id() => DateTime.t()}
  def joined_at(%User{id: user_id}), do: Membership.joined_at(user_id)

  # Everyone who shares a community with the user and which ones, narrowed to one community if given
  @spec co_members(User.t(), nil | T.id()) :: %{T.id() => [T.id()]}
  def co_members(%User{id: id} = user, community_id \\ nil) do
    ids = user |> community_ids() |> Enum.filter(&(community_id in [nil, &1]))

    Membership.co_members(id, ids)
  end

  # For each viewer, the given people who share a community with them
  @spec sharing([T.id()], [T.id()]) :: %{T.id() => [T.id()]}
  def sharing(user_ids, viewer_ids) when is_list(user_ids) and is_list(viewer_ids),
    do: Membership.sharing(user_ids, viewer_ids)

  @spec member_roles(T.id()) :: %{T.id() => [String.t()]}
  def member_roles(community_id) when is_binary(community_id) do
    default = community_id |> Role.for_community() |> Enum.find(& &1.is_default)

    community_id
    |> Membership.role_keys()
    |> Map.new(fn
      {user_id, []} when default != nil -> {user_id, [default.key]}
      member -> member
    end)
  end

  @spec member_count(T.id()) :: non_neg_integer()
  def member_count(community_id) when is_binary(community_id), do: Membership.count(community_id)

  @spec member_counts([T.id()]) :: %{T.id() => pos_integer()}
  def member_counts(community_ids) when is_list(community_ids),
    do: Membership.counts(community_ids)

  # Counts only the given people, such as those online now
  @spec member_counts([T.id()], [T.id()]) :: %{T.id() => pos_integer()}
  def member_counts(community_ids, user_ids) when is_list(community_ids) and is_list(user_ids),
    do: Membership.counts(community_ids, user_ids)

  @spec shared_community_ids([T.id()]) :: [T.id()]
  def shared_community_ids(user_ids) when is_list(user_ids),
    do: Membership.community_ids_of(user_ids)

  @spec member?(User.t(), T.id()) :: boolean()
  def member?(%User{id: user_id}, community_id) do
    Membership.exists?(user_id: user_id, community_id: community_id)
  end

  @spec share_community?(User.t(), User.t()) :: boolean()
  def share_community?(%User{id: a}, %User{id: b}) do
    Membership.shared?(a, b)
  end

  @spec get_membership(User.t(), T.id()) :: {:ok, Membership.t()} | {:error, :not_found}
  def get_membership(%User{id: user_id}, community_id) do
    case Membership.get(user_id: user_id, community_id: community_id, preload: :roles) do
      nil -> {:error, :not_found}
      %Membership{} = membership -> {:ok, with_permissions(membership)}
    end
  end

  # Unknown keys are ignored
  @spec set_roles(Membership.t(), [String.t()]) :: {:ok, Membership.t()} | {:error, Changeset.t()}
  def set_roles(%Membership{} = membership, keys) when is_list(keys) do
    roles = Role.with_keys(membership.community_id, keys)
    result = Membership.set_roles(membership, roles)

    with {:ok, membership} <- result, do: {:ok, with_permissions(membership)}
  end

  @spec holders(T.id(), String.t()) :: [T.id()]
  def holders(community_id, permission) when is_binary(community_id) and is_binary(permission) do
    explicit = Membership.holders(community_id, permission, @owner)

    granted? =
      community_id
      |> default_roles()
      |> Enum.any?(&(permission in &1.permissions))

    by_default =
      case granted? do
        true -> Membership.without_roles(community_id)
        false -> []
      end

    Enum.uniq(explicit ++ by_default)
  end

  # A member with no roles of their own holds the default ones
  @spec role_ids(User.t(), [T.id()]) :: [T.id()]
  def role_ids(%User{id: user_id}, community_ids) when is_list(community_ids) do
    [user_id: user_id, community_id: community_ids, preload: :roles]
    |> Membership.all()
    |> Enum.flat_map(&held_roles/1)
    |> Enum.map(& &1.id)
  end

  @spec communities_with(User.t(), String.t(), [T.id()]) :: [T.id()]
  def communities_with(%User{id: user_id}, permission, community_ids)
      when is_binary(permission) and is_list(community_ids) do
    [user_id: user_id, community_id: community_ids, preload: :roles]
    |> Membership.all()
    |> Enum.filter(&(permission in with_permissions(&1).permissions))
    |> Enum.map(& &1.community_id)
  end

  @spec permissions_for(User.t(), T.id()) :: [String.t()]
  def permissions_for(%User{} = user, community_id) do
    case get_membership(user, community_id) do
      {:ok, membership} -> membership.permissions
      {:error, :not_found} -> []
    end
  end

  # Resource is an Object, or just the type for instance resources
  @spec can?(User.t(), atom(), Object.t() | map() | atom()) :: boolean()
  def can?(%User{} = user, action, %Object{} = object) when is_atom(action) do
    permission = Spec.permission(object.type, action)

    case Spec.rule(permission) do
      nil -> false
      %{scope: :instance} -> user.is_instance_admin
      rule -> community_can?(user, permission, rule, object)
    end
  end

  def can?(%User{} = user, action, type) when is_atom(type) do
    can?(user, action, %Object{type: type})
  end

  def can?(%User{} = user, action, %{type: _type} = attrs) do
    can?(user, action, Object.from(attrs))
  end

  defp community_can?(_user, _permission, _rule, %Object{community_id: nil}), do: false

  defp community_can?(user, permission, rule, object) do
    case get_membership(user, object.community_id) do
      {:ok, membership} ->
        permission in membership.permissions or (rule.author and object.author_id == user.id)

      {:error, :not_found} ->
        false
    end
  end

  defp with_permissions(%Membership{} = membership) do
    roles = held_roles(membership)

    permissions =
      case Enum.any?(roles, &(&1.key == @owner)) do
        true -> Spec.permissions(:community)
        false -> Enum.flat_map(roles, & &1.permissions)
      end

    %{membership | permissions: permissions |> Enum.uniq() |> Enum.sort()}
  end

  defp held_roles(%Membership{roles: [], community_id: community_id}),
    do: default_roles(community_id)

  defp held_roles(%Membership{roles: roles}), do: roles

  defp default_roles(community_id), do: Role.all(community_id: community_id, is_default: true)
end
