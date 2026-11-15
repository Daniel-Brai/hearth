defmodule Hearth.Chat.Pin do
  use Hearth.Repo.Schema, prefix: "chat", primary_key: false

  alias Hearth.Common.T

  @most 3

  schema "pins" do
    field :message_id, Ecto.UUID, primary_key: true
    field :room_id, Ecto.UUID
    field :pinned_by_id, Ecto.UUID

    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{
          message_id: T.id(),
          room_id: T.id(),
          pinned_by_id: nil | T.id(),
          inserted_at: DateTime.t()
        }

  @spec add(T.id(), T.id(), T.id()) :: :pinned | :already
  def add(room_id, message_id, user_id) do
    pinned = room_id |> newest_first() |> lock("FOR UPDATE") |> select([p], p.message_id)

    case message_id in Repo.all(pinned) do
      true ->
        :already

      false ->
        row = %{
          message_id: message_id,
          room_id: room_id,
          pinned_by_id: user_id,
          inserted_at: DateTime.utc_now()
        }

        {1, nil} = Repo.insert_all(__MODULE__, [row])
        drop_oldest(room_id)

        :pinned
    end
  end

  @spec message_ids(T.id()) :: [T.id()]
  def message_ids(room_id),
    do: room_id |> newest_first() |> select([p], p.message_id) |> Repo.all()

  @spec remove(T.id()) :: :ok
  def remove(message_id) do
    {_count, nil} = __MODULE__ |> where(message_id: ^message_id) |> Repo.delete_all()

    :ok
  end

  defp drop_oldest(room_id) do
    kept = room_id |> newest_first() |> limit(@most) |> select([p], p.message_id)

    __MODULE__
    |> where([p], p.room_id == ^room_id and p.message_id not in subquery(kept))
    |> Repo.delete_all()
  end

  defp newest_first(room_id) do
    __MODULE__
    |> where(room_id: ^room_id)
    |> order_by(desc: :inserted_at, desc: :message_id)
  end
end
