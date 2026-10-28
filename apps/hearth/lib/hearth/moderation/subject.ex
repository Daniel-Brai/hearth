defmodule Hearth.Moderation.Subject do
  alias Hearth.Chat
  alias Hearth.Chat.Message
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Forum.Post
  alias Hearth.Forum.Reply

  @fields ~w[type content author_id community_id room_id post_id conversation_id]a
  @enforce_keys @fields
  defstruct @fields

  @type type :: :post | :reply | :message
  @type t :: %__MODULE__{
          type: type(),
          content: Post.t() | Reply.t() | Message.t(),
          author_id: T.id(),
          community_id: nil | T.id(),
          room_id: nil | T.id(),
          post_id: nil | T.id(),
          conversation_id: nil | T.id()
        }

  @spec load(type(), T.id()) :: {:ok, t()} | {:error, :not_found}
  def load(:post, id) do
    with {:ok, post} <- Forum.get_post(id: id) do
      {:ok, new(:post, post, community_id: post.community_id, post_id: post.id)}
    end
  end

  def load(:reply, id) do
    with {:ok, reply} <- Forum.get_reply(id),
         {:ok, post} <- Forum.get_post(id: reply.post_id) do
      {:ok, new(:reply, reply, community_id: post.community_id, post_id: post.id)}
    end
  end

  def load(:message, id) do
    with {:ok, message} <- Chat.get_message(id) do
      place(message)
    end
  end

  def load(_type, _id), do: {:error, :not_found}

  @spec direct?(t()) :: boolean()
  def direct?(%__MODULE__{community_id: nil}), do: true
  def direct?(%__MODULE__{}), do: false

  defp place(%Message{room_id: nil} = message) do
    {:ok, new(:message, message, conversation_id: message.conversation_id)}
  end

  defp place(%Message{room_id: room_id} = message) do
    with {:ok, room} <- Communities.get_room(id: room_id) do
      {:ok, new(:message, message, community_id: room.community_id, room_id: room.id)}
    end
  end

  defp new(type, content, place) do
    %__MODULE__{
      type: type,
      content: content,
      author_id: content.author_id,
      community_id: place[:community_id],
      room_id: place[:room_id],
      post_id: place[:post_id],
      conversation_id: place[:conversation_id]
    }
  end
end
