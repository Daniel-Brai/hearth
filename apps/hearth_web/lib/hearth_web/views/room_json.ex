defmodule HearthWeb.RoomJSON do
  @fields ~w[id community_id type slug name topic group_id position moderation access archived_at]a

  def archived(%{rooms: rooms}), do: Enum.map(rooms, &serialize/1)
  def create(%{room: room}), do: serialize(room)
  def update(%{room: room}), do: serialize(room)
  def archive(%{room: room}), do: serialize(room)
  def restore(%{room: room}), do: serialize(room)
  def create_group(%{group: group}), do: group(group)
  def update_group(%{group: group}), do: group(group)

  @spec group(map()) :: map()
  def group(group), do: Map.take(group, ~w[id community_id name position]a)

  # Room roles are loaded only for people who manage rooms
  @spec serialize(map()) :: map()
  def serialize(%{room_roles: room_roles} = room) when is_list(room_roles),
    do: room |> base() |> Map.put(:role_ids, Enum.map(room_roles, & &1.role_id))

  def serialize(room), do: base(room)

  defp base(room),
    do: room |> Map.take(@fields) |> Map.put(:settings, Map.from_struct(room.settings))
end
