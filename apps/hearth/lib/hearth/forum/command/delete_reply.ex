defmodule Hearth.Forum.Command.DeleteReply do
  alias Ecto.Changeset
  alias Hearth.Forum.Command.CreateReply
  alias Hearth.Forum.Reply
  alias Hearth.Repo

  @spec execute(Reply.t()) :: {:ok, Reply.t()} | {:error, Changeset.t()}
  def execute(%Reply{child_count: 0} = reply) do
    Repo.transact(fn ->
      with {:ok, reply} <- Repo.delete(reply) do
        :ok = CreateReply.removed(reply)
        {:ok, reply}
      end
    end)
  end
end
