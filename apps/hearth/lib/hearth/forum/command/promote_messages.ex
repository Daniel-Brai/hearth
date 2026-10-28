defmodule Hearth.Forum.Command.PromoteMessages do
  import Ecto.Query

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Chat.Message
  alias Hearth.Communities.Community
  alias Hearth.Communities.Room
  alias Hearth.Forum.Command.CreatePost
  alias Hearth.Forum.Command.QueueScreening
  alias Hearth.Forum.Post
  alias Hearth.Forum.PostWatch
  alias Hearth.Forum.Reply
  alias Hearth.Media
  alias Hearth.Repo
  alias Hearth.Repo.Tree

  @tree [parent: :parent_reply_id, root: :root_reply_id]

  @spec execute(User.t(), Community.t(), Room.t(), [Message.t(), ...], map()) ::
          {:ok, Post.t()} | {:error, Changeset.t()}
  def execute(%User{} = promoter, %Community{} = community, %Room{} = room, messages, params) do
    [first | rest] = messages
    files = Media.list_attachments(:message, Enum.map(messages, & &1.id))

    post = %Post{
      community_id: community.id,
      author_id: first.author_id,
      source_message_id: first.id,
      source_room_id: room.id,
      source_message_count: length(messages),
      promoted_by_id: promoter.id
    }

    params = params |> Map.take([:title, :kind_id]) |> Map.put(:body, first.body)

    Repo.transact(fn ->
      with {:ok, post} <- Post.insert(post, params),
           :ok <- Media.link_attachments(:post, post.id, media_ids(files, first)),
           {:ok, post} <- CreatePost.tag(post, community),
           :ok <- QueueScreening.post(post, community),
           :ok <- PostWatch.put(post.author_id, post.id, true),
           :ok <- reply_all(post, rest, files) do
        {:ok, %{post | reply_count: length(rest)}}
      end
    end)
  end

  defp reply_all(_post, [], _files), do: :ok

  defp reply_all(post, messages, files) do
    result =
      Enum.reduce_while(messages, :ok, fn message, :ok ->
        case reply(post, message, media_ids(files, message)) do
          {:ok, _reply} -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    with :ok <- result do
      Post
      |> where(id: ^post.id)
      |> Repo.update_all(inc: [reply_count: length(messages)])

      :ok
    end
  end

  defp reply(post, message, media_ids) do
    reply =
      struct!(%Reply{post_id: post.id, author_id: message.author_id}, Tree.place(nil, @tree))

    with {:ok, reply} <- Reply.insert(reply, %{body: message.body, attachment_ids: media_ids}),
         :ok <- Media.link_attachments(:reply, reply.id, media_ids),
         :ok <- QueueScreening.reply(reply) do
      :ok = Tree.added(reply, message.author_id, @tree)
      :ok = PostWatch.put(message.author_id, post.id, true, keep: true)

      {:ok, reply}
    end
  end

  defp media_ids(files, message), do: files |> Map.get(message.id, []) |> Enum.map(& &1.media_id)
end
