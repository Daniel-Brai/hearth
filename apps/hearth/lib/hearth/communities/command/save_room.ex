defmodule Hearth.Communities.Command.SaveRoom do
  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Communities.Room
  alias Hearth.Communities.RoomRole
  alias Hearth.Repo

  # Role ids are left alone when nil, so a rename keeps who can see the room
  @spec execute(Room.t(), map(), nil | [T.id()]) :: {:ok, Room.t()} | {:error, Changeset.t()}
  def execute(%Room{} = room, %{} = params, role_ids) do
    Repo.transact(fn ->
      with {:ok, saved} <- save(room, params),
           :ok <- put_roles(saved, role_ids) do
        {:ok, Repo.preload(saved, :room_roles, force: true)}
      end
    end)
  end

  defp save(%Room{id: nil} = room, params), do: Room.insert(room, params)
  defp save(%Room{} = room, params), do: Room.update(room, params)

  defp put_roles(_room, nil), do: :ok
  defp put_roles(room, role_ids), do: RoomRole.replace(room, role_ids)
end
