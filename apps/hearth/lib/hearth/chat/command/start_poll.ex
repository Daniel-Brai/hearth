defmodule Hearth.Chat.Command.StartPoll do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Chat.Command.SendMessage
  alias Hearth.Chat.Message
  alias Hearth.Chat.Poll
  alias Hearth.Chat.Worker.ClosePoll
  alias Hearth.Communities.Room
  alias Hearth.Repo

  # The question is the message's body, so the poll reads like any other line in the chat
  @spec execute(User.t(), Room.t(), map()) :: {:ok, Message.t()} | {:error, Changeset.t()}
  def execute(%User{} = author, %Room{} = room, %{} = params) do
    Repo.transact(fn ->
      with {:ok, message} <- ask(author, room, params),
           {:ok, poll} <- Poll.insert(%Poll{message_id: message.id, room_id: room.id}, params),
           :ok <- close_later(poll) do
        {:ok, message}
      end
    end)
  end

  defp ask(author, room, params) do
    fields = [kind: :poll, room_id: room.id]
    SendMessage.execute(author, fields, nil, %{body: params[:question]})
  end

  defp close_later(%Poll{closes_at: nil}), do: :ok

  defp close_later(%Poll{} = poll) do
    with {:ok, _job} <- ClosePoll.enqueue(poll), do: :ok
  end
end
