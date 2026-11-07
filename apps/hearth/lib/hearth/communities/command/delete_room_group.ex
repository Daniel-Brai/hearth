defmodule Hearth.Communities.Command.DeleteRoomGroup do
  alias Ecto.Changeset
  alias Hearth.Communities.Room
  alias Hearth.Communities.RoomGroup
  alias Hearth.Repo

  @spec execute(RoomGroup.t()) :: {:ok, RoomGroup.t()} | {:error, Changeset.t()}
  def execute(%RoomGroup{} = group) do
    Repo.transact(fn ->
      :ok = Room.ungroup(group.community_id, group.id)
      RoomGroup.delete(group)
    end)
  end
end
