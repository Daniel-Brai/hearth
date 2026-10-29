defmodule Hearth.Communities.RoomRole do
  use Hearth.Repo.Schema, prefix: "communities", primary_key: false

  alias Hearth.Common.T
  alias Hearth.Communities.Room

  schema "room_roles" do
    belongs_to :room, Room, primary_key: true
    field :role_id, Ecto.UUID, primary_key: true
  end

  @type t :: %__MODULE__{room_id: T.id(), role_id: T.id()}

  @spec replace(Room.t(), [T.id()]) :: :ok
  def replace(%Room{id: room_id}, role_ids) when is_list(role_ids) do
    __MODULE__
    |> where([rr], rr.room_id == ^room_id)
    |> Repo.delete_all()

    rows = for role_id <- Enum.uniq(role_ids), do: %{room_id: room_id, role_id: role_id}
    {_count, nil} = Repo.insert_all(__MODULE__, rows)

    :ok
  end
end
