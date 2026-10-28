defmodule Hearth.Forum.Command.CreateReply do
  import Ecto.Query

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Forum.Command.QueueScreening
  alias Hearth.Forum.Post
  alias Hearth.Forum.PostWatch
  alias Hearth.Forum.Reply
  alias Hearth.Media
  alias Hearth.Repo
  alias Hearth.Repo.Tree

  @tree [parent: :parent_reply_id, root: :root_reply_id]

  @spec execute(User.t(), Post.t(), nil | Reply.t(), map()) ::
          {:ok, Reply.t()} | {:error, :too_many_attachments | :invalid_attachment | Changeset.t()}
  def execute(%User{} = author, %Post{} = post, parent, %{} = params) do
    reply = struct!(%Reply{post_id: post.id, author_id: author.id}, Tree.place(parent, @tree))

    Repo.transact(fn ->
      with {:ok, reply} <- Reply.insert(reply, params),
           :ok <- attach(author, reply),
           :ok <- QueueScreening.reply(reply) do
        :ok = Tree.added(reply, author.id, @tree)
        :ok = PostWatch.put(author.id, post.id, true, keep: true)
        count(post, 1)

        {:ok, reply}
      end
    end)
  end

  @spec attach(User.t(), Reply.t()) :: :ok | {:error, :too_many_attachments | :invalid_attachment}
  def attach(%User{}, %Reply{attachment_ids: nil}), do: :ok

  def attach(%User{} = author, %Reply{} = reply),
    do: Media.put_attachments(author, :reply, reply.id, reply.attachment_ids)

  @spec removed(Reply.t()) :: :ok
  def removed(%Reply{} = reply) do
    :ok = Tree.removed(reply, @tree)
    count(%Post{id: reply.post_id}, -1)

    :ok
  end

  defp count(post, by) do
    activity = if by > 0, do: [last_activity_at: DateTime.utc_now()], else: []

    Post
    |> where(id: ^post.id)
    |> Repo.update_all(inc: [reply_count: by], set: activity)
  end
end
