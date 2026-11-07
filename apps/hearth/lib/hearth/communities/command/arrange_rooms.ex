defmodule Hearth.Communities.Command.ArrangeRooms do
  alias Hearth.Common.T
  alias Hearth.Communities.Room
  alias Hearth.Communities.RoomGroup
  alias Hearth.Repo

  @type layout :: %{groups: [%{id: T.id(), room_ids: [T.id()]}], room_ids: [T.id()]}

  @spec execute(T.id(), layout()) :: :ok | {:error, :layout_mismatch}
  def execute(community_id, %{groups: groups, room_ids: loose}) do
    placed = loose ++ Enum.flat_map(groups, & &1.room_ids)

    result =
      Repo.transact(fn ->
        with :ok <- same(RoomGroup.ids_in(community_id), Enum.map(groups, & &1.id)),
             :ok <- same(Room.ids_in(community_id), placed) do
          :ok = place_groups(groups)
          :ok = Room.place(loose, nil)
          {:ok, community_id}
        end
      end)

    with {:ok, _community_id} <- result, do: :ok
  end

  defp place_groups(groups) do
    groups
    |> Enum.with_index()
    |> Enum.each(fn {group, position} ->
      :ok = RoomGroup.put_position(group.id, position)
      :ok = Room.place(group.room_ids, group.id)
    end)
  end

  defp same(known, given) do
    case length(given) == length(Enum.uniq(given)) and MapSet.new(known) == MapSet.new(given) do
      true -> :ok
      false -> {:error, :layout_mismatch}
    end
  end
end
