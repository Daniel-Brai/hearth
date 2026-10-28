defmodule HearthWeb.UnreadJSON do
  def show(%{unread: %{rooms: rooms, conversations: conversations}}) do
    %{
      rooms: Enum.map(rooms, &%{id: &1.room_id, community_id: &1.community_id, count: &1.count}),
      conversations: Enum.map(conversations, fn {id, count} -> %{id: id, count: count} end)
    }
  end
end
