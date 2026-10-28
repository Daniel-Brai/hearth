defmodule Hearth.Forum.Command.CreatePost do
  import Ecto.Query

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias Hearth.Forum.Command.QueueScreening
  alias Hearth.Forum.Post
  alias Hearth.Forum.PostWatch
  alias Hearth.Forum.Tag
  alias Hearth.Media
  alias Hearth.Repo

  @spec execute(User.t(), Community.t(), map()) ::
          {:ok, Post.t()} | {:error, :too_many_attachments | :invalid_attachment | Changeset.t()}
  def execute(%User{} = author, %Community{} = community, %{} = params) do
    post = %Post{community_id: community.id, author_id: author.id}

    Repo.transact(fn ->
      with {:ok, post} <- Post.insert(post, params),
           :ok <- attach(author, post),
           {:ok, post} <- tag(post, community),
           :ok <- QueueScreening.post(post, community),
           :ok <- PostWatch.put(author.id, post.id, true) do
        {:ok, post}
      end
    end)
  end

  @spec attach(User.t(), Post.t()) :: :ok | {:error, :too_many_attachments | :invalid_attachment}
  def attach(%User{}, %Post{attachment_ids: nil}), do: :ok

  def attach(%User{} = author, %Post{} = post),
    do: Media.put_attachments(author, :post, post.id, post.attachment_ids)

  @spec tag(Post.t(), Community.t()) :: {:ok, Post.t()} | {:error, Changeset.t()}
  def tag(%Post{} = post, %Community{} = community) do
    rooms =
      community
      |> Communities.list_rooms()
      |> MapSet.new(& &1.slug)

    names =
      post.body
      |> Common.refs()
      |> Enum.reject(&MapSet.member?(rooms, &1))

    post
    |> Repo.preload(:tags)
    |> Changeset.change()
    |> Changeset.put_assoc(:tags, upsert_tags(community.id, names))
    |> Repo.update()
  end

  defp upsert_tags(_community_id, []), do: []

  defp upsert_tags(community_id, names) do
    now = DateTime.utc_now()

    rows =
      Enum.map(names, fn name ->
        %{
          id: Common.new_id(),
          community_id: community_id,
          name: name,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(Tag, rows, on_conflict: :nothing, conflict_target: [:community_id, :name])

    Tag
    |> where([t], t.community_id == ^community_id and t.name in ^names)
    |> Repo.all()
  end
end
