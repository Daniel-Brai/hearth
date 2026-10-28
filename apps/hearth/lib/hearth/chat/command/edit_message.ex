defmodule Hearth.Chat.Command.EditMessage do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Chat.Command.QueueScreening
  alias Hearth.Chat.Command.SendMessage
  alias Hearth.Chat.Message
  alias Hearth.Repo

  @spec execute(User.t(), Message.t(), map()) ::
          {:ok, Message.t()}
          | {:error, :too_many_attachments | :invalid_attachment | Changeset.t()}
  def execute(%User{} = author, %Message{} = message, %{} = params) do
    Repo.transact(fn ->
      with {:ok, message} <- Message.edit(message, params),
           :ok <- SendMessage.attach(author, message),
           :ok <- QueueScreening.message(message) do
        {:ok, message}
      end
    end)
  end
end
