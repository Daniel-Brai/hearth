defmodule HearthWeb.CommunityRoleJSON do
  @fields ~w[id key name color position is_default is_system permissions]a

  def index(%{roles: roles}), do: Enum.map(roles, &Map.take(&1, @fields))
  def show(%{role: role}), do: Map.take(role, @fields)
  def member_roles(%{user_id: user_id, keys: keys}), do: %{user_id: user_id, keys: keys}
end
