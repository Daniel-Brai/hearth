defmodule Hearth.Forum.PostWatch do
  use Hearth.Repo.Schema, prefix: "forum", primary_key: false

  import Ecto.Query

  alias Hearth.Common.T
  alias Hearth.Repo

  schema "post_watches" do
    field :user_id, Ecto.UUID, primary_key: true
    field :post_id, Ecto.UUID, primary_key: true
    field :watching, :boolean

    timestamps()
  end

  @type t :: %__MODULE__{
          user_id: T.id(),
          post_id: T.id(),
          watching: boolean()
        }

  # keep leaves an earlier choice alone so replying doesn't undo stopping
  @spec put(T.id(), T.id(), boolean(), keyword()) :: :ok
  def put(user_id, post_id, watching, opts \\ []) do
    now = DateTime.utc_now()

    conflict =
      if opts[:keep],
        do: :nothing,
        else: [set: [watching: watching, updated_at: now]]

    Repo.insert_all(
      __MODULE__,
      [
        %{
          user_id: user_id,
          post_id: post_id,
          watching: watching,
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: conflict,
      conflict_target: [:user_id, :post_id]
    )

    :ok
  end

  @spec watcher_ids(T.id()) :: [T.id()]
  def watcher_ids(post_id) do
    query = from w in __MODULE__, where: w.post_id == ^post_id and w.watching, select: w.user_id

    Repo.all(query)
  end

  @spec watched(T.id(), [T.id()]) :: MapSet.t(T.id())
  def watched(user_id, post_ids) do
    query =
      from w in __MODULE__,
        where: w.user_id == ^user_id and w.post_id in ^post_ids and w.watching,
        select: w.post_id

    query |> Repo.all() |> MapSet.new()
  end
end
