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

  defp save(community_id, params) when is_binary(community_id),
    do: Room.insert(%Room{community_id: community_id}, params)

  defp save(%Room{} = room, params), do: Room.update(room, params)

  defp put_roles(_room, nil), do: :ok
  defp put_roles(room, role_ids), do: RoomRole.replace(room, role_ids)
end
