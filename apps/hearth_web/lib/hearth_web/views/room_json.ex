defmodule HearthWeb.RoomJSON do
  @fields ~w[id community_id type slug name topic position moderation archived_at]a

  def archived(%{rooms: rooms}), do: Enum.map(rooms, &serialize/1)
  def create(%{room: room}), do: serialize(room)
  def update(%{room: room}), do: serialize(room)
  def archive(%{room: room}), do: serialize(room)
  def restore(%{room: room}), do: serialize(room)

  @spec serialize(map()) :: map()
  def serialize(room), do: Map.take(room, @fields)
end
