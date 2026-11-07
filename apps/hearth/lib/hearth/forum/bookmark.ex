defmodule Hearth.Forum.Bookmark do
  use Hearth.Repo.Schema, prefix: "forum", primary_key: false

  alias Hearth.Common.T

  schema "bookmarks" do
    field :user_id, Ecto.UUID, primary_key: true
    field :post_id, Ecto.UUID, primary_key: true

    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{
          user_id: T.id(),
          post_id: T.id(),
          inserted_at: DateTime.t()
        }

  @spec put(T.id(), T.id()) :: :ok
  def put(user_id, post_id) do
    row = %{user_id: user_id, post_id: post_id, inserted_at: DateTime.utc_now()}

    Repo.insert_all(__MODULE__, [row], on_conflict: :nothing)

    :ok
  end

  @spec remove(T.id(), T.id()) :: :ok
  def remove(user_id, post_id) do
    query = from b in __MODULE__, where: b.user_id == ^user_id and b.post_id == ^post_id

    Repo.delete_all(query)

    :ok
  end

  @spec bookmarked(T.id(), [T.id()]) :: MapSet.t(T.id())
  def bookmarked(user_id, post_ids) do
    query =
      from b in __MODULE__,
        where: b.user_id == ^user_id and b.post_id in ^post_ids,
        select: b.post_id

    query |> Repo.all() |> MapSet.new()
  end
end
