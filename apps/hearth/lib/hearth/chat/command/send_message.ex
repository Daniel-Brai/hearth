defmodule Hearth.Chat.Command.SendMessage do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Chat.Command.QueueScreening
  alias Hearth.Chat.Message
  alias Hearth.Media
  alias Hearth.Repo
  alias Hearth.Repo.Tree

  @tree [parent: :reply_to_id, root: :thread_root_id]

  @spec execute(User.t(), keyword(), nil | Message.t(), map()) ::
          {:ok, Message.t()}
          | {:error, :too_many_attachments | :invalid_attachment | Changeset.t()}
  def execute(%User{} = author, place, parent, %{} = params) when is_list(place) do
    message =
      %Message{author_id: author.id}
      |> struct!(place)
      |> struct!(Tree.place(parent, @tree))

    Repo.transact(fn ->
      with {:ok, message} <- Message.insert(message, params),
           :ok <- attach(author, message),
           :ok <- QueueScreening.message(message) do
        :ok = Tree.added(message, author.id, @tree)
        {:ok, message}
      end
    end)
  end

  # A message sent without attachment_ids keeps the ones it has
  @spec attach(User.t(), Message.t()) ::
          :ok | {:error, :too_many_attachments | :invalid_attachment}
  def attach(%User{}, %Message{attachment_ids: nil}), do: :ok

  def attach(%User{} = author, %Message{} = message),
    do: Media.put_attachments(author, :message, message.id, message.attachment_ids)

  @spec removed(Message.t()) :: :ok
  def removed(%Message{} = message), do: Tree.removed(message, @tree)
end
