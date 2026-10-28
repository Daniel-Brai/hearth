defmodule HearthWeb.CommunityMemberJSON do
  alias HearthWeb.UserJSON

  def index(%{users: users, roles: roles}),
    do: Enum.map(users, &%{user: UserJSON.summary(&1), role_keys: Map.get(roles, &1.id, [])})
end
