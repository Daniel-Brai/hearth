defmodule Hearth.Chat.Command.DeleteMessage do
  alias Ecto.Changeset
  alias Hearth.Chat.Command.SendMessage
  alias Hearth.Chat.Message
  alias Hearth.Repo

  @spec execute(Message.t()) :: {:ok, Message.t()} | {:error, Changeset.t()}
  def execute(%Message{child_count: 0} = message) do
    Repo.transact(fn ->
      with {:ok, message} <- Repo.delete(message) do
        :ok = SendMessage.removed(message)
        {:ok, message}
      end
    end)
  end
end
