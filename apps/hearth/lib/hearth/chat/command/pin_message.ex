defmodule Hearth.Chat.Command.PinMessage do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Chat.Message
  alias Hearth.Chat.Pin
  alias Hearth.Common
  alias Hearth.Communities.Room
  alias Hearth.Repo

  @excerpt 80

  @spec execute(User.t(), Room.t(), Message.t()) ::
          {:ok, nil | Message.t()} | {:error, Changeset.t()}
  def execute(%User{} = user, %Room{} = room, %Message{} = message) do
    Repo.transact(fn ->
      case Pin.add(room.id, message.id, user.id) do
        :already -> {:ok, nil}
        :pinned -> notice(user, room, message)
      end
    end)
  end

  defp notice(user, room, message) do
    notice = %Message{room_id: room.id, author_id: user.id, kind: :pinned}

    Message.insert(notice, %{body: Common.excerpt(message.body, @excerpt)})
  end
end
