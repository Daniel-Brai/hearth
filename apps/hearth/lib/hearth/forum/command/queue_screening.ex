defmodule Hearth.Forum.Command.QueueScreening do
  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias Hearth.Forum.Post
  alias Hearth.Forum.Reply
  alias Hearth.Media
  alias Hearth.ScreeningPolicy

  @spec post(Post.t(), Community.t()) :: :ok | {:error, term()}
  def post(%Post{} = post, %Community{} = community) do
    ScreeningPolicy.enqueue(:post, post.id, files?(:post, post), fn ->
      Communities.moderation_level(community, nil)
    end)
  end

  @spec reply(Reply.t()) :: :ok | {:error, term()}
  def reply(%Reply{} = reply) do
    ScreeningPolicy.enqueue(:reply, reply.id, files?(:reply, reply), fn ->
      level_of_post(reply.post_id)
    end)
  end

  # Sent with files, or kept the ones it had
  defp files?(_owner, %{attachment_ids: [_ | _]}), do: true
  defp files?(_owner, %{attachment_ids: []}), do: false

  defp files?(owner, %{id: id}),
    do: fn -> owner |> Media.list_attachments([id]) |> Map.get(id, []) != [] end

  defp level_of_post(post_id) do
    with %Post{community_id: community_id} <- Post.get(id: post_id),
         {:ok, community} <- Communities.get_community(id: community_id) do
      Communities.moderation_level(community, nil)
    else
      _gone -> :none
    end
  end
end
