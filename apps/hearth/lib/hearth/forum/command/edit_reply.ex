defmodule Hearth.Forum.Command.EditReply do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Forum.Command.CreateReply
  alias Hearth.Forum.Command.QueueScreening
  alias Hearth.Forum.Reply
  alias Hearth.Repo

  @spec execute(User.t(), Reply.t(), map()) ::
          {:ok, Reply.t()} | {:error, :too_many_attachments | :invalid_attachment | Changeset.t()}
  def execute(%User{} = author, %Reply{} = reply, %{} = params) do
    Repo.transact(fn ->
      with {:ok, reply} <- Reply.edit(reply, params),
           :ok <- CreateReply.attach(author, reply),
           :ok <- QueueScreening.reply(reply) do
        {:ok, reply}
      end
    end)
  end
end
