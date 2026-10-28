defmodule Hearth.Chat.RoomRead do
  use Hearth.Repo.Schema, prefix: "chat", primary_key: false

  alias Hearth.Common.T

  schema "room_reads" do
    field :user_id, Ecto.UUID, primary_key: true
    field :room_id, Ecto.UUID, primary_key: true
    field :last_read_message_id, Ecto.UUID

    timestamps()
  end

  @type t :: %__MODULE__{
          user_id: T.id(),
          room_id: T.id(),
          last_read_message_id: nil | T.id()
        }
end
