defmodule Hearth.Forum.Command.UpdatePost do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Communities
  alias Hearth.Forum.Command.CreatePost
  alias Hearth.Forum.Command.QueueScreening
  alias Hearth.Forum.Post
  alias Hearth.Repo

  @spec execute(User.t(), Post.t(), map()) ::
          {:ok, Post.t()}
          | {:error, :not_found | :too_many_attachments | :invalid_attachment | Changeset.t()}
  def execute(%User{} = author, %Post{} = post, %{} = params) do
    Repo.transact(fn ->
      with {:ok, post} <- Post.edit(post, params),
           :ok <- CreatePost.attach(author, post),
           {:ok, community} <- Communities.get_community(id: post.community_id),
           {:ok, post} <- CreatePost.tag(post, community),
           :ok <- QueueScreening.post(post, community) do
        {:ok, post}
      end
    end)
  end
end
