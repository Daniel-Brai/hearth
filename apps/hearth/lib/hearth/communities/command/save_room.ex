defmodule Hearth.Communities.Command.SaveRoom do
  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Communities.Room
  alias Hearth.Communities.RoomRole
  alias Hearth.Repo

  # A community id makes a new room. Role ids are left alone when nil, so a rename keeps who can see it
  @spec execute(T.id() | Room.t(), map(), nil | [T.id()]) ::
          {:ok, Room.t()} | {:error, Changeset.t()}
  def execute(room_or_community_id, %{} = params, role_ids) do
    Repo.transact(fn ->
      with {:ok, saved} <- save(room_or_community_id, params),
           :ok <- put_roles(saved, role_ids) do
        {:ok, Repo.preload(saved, :room_roles, force: true)}
      end
    end)
  end

  defp save(community_id, params) when is_binary(community_id) do
    params = Map.put_new_lazy(params, :position, fn -> last(community_id, params[:group_id]) end)

    Room.insert(%Room{community_id: community_id}, params)
  end

  defp save(%Room{} = room, params), do: Room.update(room, placed(room, params))

  defp placed(%Room{group_id: same}, %{group_id: same} = params), do: params

  defp placed(room, %{group_id: group_id} = params),
    do: Map.put_new_lazy(params, :position, fn -> last(room.community_id, group_id) end)

  defp placed(_room, params), do: params

  defp last(community_id, group_id), do: Room.next_position(community_id, group_id)

  defp put_roles(_room, nil), do: :ok
  defp put_roles(room, role_ids), do: RoomRole.replace(room, role_ids)
end
