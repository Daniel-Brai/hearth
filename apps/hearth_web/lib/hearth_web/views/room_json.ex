defmodule HearthWeb.RoomJSON do
  @fields ~w[id community_id type slug name topic position moderation access archived_at]a

  def archived(%{rooms: rooms}), do: Enum.map(rooms, &serialize/1)
  def create(%{room: room}), do: serialize(room)
  def update(%{room: room}), do: serialize(room)
  def archive(%{room: room}), do: serialize(room)
  def restore(%{room: room}), do: serialize(room)

  # Room roles are loaded only for people who manage rooms
  @spec serialize(map()) :: map()
  def serialize(%{room_roles: room_roles} = room) when is_list(room_roles),
    do: room |> Map.take(@fields) |> Map.put(:role_ids, Enum.map(room_roles, & &1.role_id))

  def serialize(room), do: Map.take(room, @fields)
end
