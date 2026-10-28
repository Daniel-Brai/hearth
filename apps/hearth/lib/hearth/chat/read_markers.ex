defmodule Hearth.Chat.ReadMarkers do
  # Message ids are UUIDv7 so an older mark never replaces a newer one

  use Hearth.Buffer, every: :timer.seconds(2)

  import Ecto.Query

  alias Hearth.Chat.ConversationMember
  alias Hearth.Chat.RoomRead
  alias Hearth.Common.T
  alias Hearth.Repo

  # The buffer compares whole number versions, and a UUIDv7 read as one keeps its time order
  @spec version(T.id()) :: non_neg_integer()
  def version(message_id) do
    <<version::unsigned-128>> = Ecto.UUID.dump!(message_id)
    version
  end

  @impl Hearth.Buffer
  def flush(entries) do
    {rooms, conversations} = Enum.split_with(entries, &match?({{:room, _, _}, _, _, _}, &1))

    flush_rooms(rooms)
    Enum.each(conversations, &flush_conversation/1)

    :ok
  end

  defp flush_rooms([]), do: :ok

  defp flush_rooms(entries) do
    now = DateTime.utc_now()

    rows =
      for {{:room, user_id, room_id}, message_id, _version, _updates} <- entries do
        %{
          user_id: user_id,
          room_id: room_id,
          last_read_message_id: message_id,
          inserted_at: now,
          updated_at: now
        }
      end

    newer =
      from r in RoomRead,
        update: [
          set: [
            last_read_message_id: fragment("EXCLUDED.last_read_message_id"),
            updated_at: fragment("EXCLUDED.updated_at")
          ]
        ],
        where:
          is_nil(r.last_read_message_id) or
            r.last_read_message_id < fragment("EXCLUDED.last_read_message_id")

    Repo.insert_all(RoomRead, rows, on_conflict: newer, conflict_target: [:user_id, :room_id])
  end

  defp flush_conversation({{:conversation, user_id, conversation_id}, message_id, _v, _n}) do
    ConversationMember
    |> where(conversation_id: ^conversation_id, user_id: ^user_id)
    |> where([m], is_nil(m.last_read_message_id) or m.last_read_message_id < ^message_id)
    |> Repo.update_all(set: [last_read_message_id: message_id])
  end
end
