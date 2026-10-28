defmodule Hearth.Repo.Tree do
  import Ecto.Query

  alias Hearth.Common.T
  alias Hearth.Repo

  @max_depth 10
  @repliers_kept 3

  # A node answering one at the deepest level goes beside it
  @spec place(nil | struct(), keyword()) :: map()
  def place(nil, opts), do: %{opts[:parent] => nil, opts[:root] => nil, depth: 0, path: []}

  def place(%module{depth: @max_depth} = parent, opts) do
    module
    |> Repo.get!(Map.fetch!(parent, opts[:parent]))
    |> place(opts)
  end

  def place(%{} = parent, opts) do
    %{
      opts[:parent] => parent.id,
      opts[:root] => Map.fetch!(parent, opts[:root]) || parent.id,
      depth: parent.depth + 1,
      path: List.insert_at(parent.path, -1, parent.id)
    }
  end

  # One statement updates every ancestor so adding a node costs the same at any depth
  @spec added(struct(), T.id(), keyword()) :: :ok
  def added(%{path: []}, _author_id, _opts), do: :ok

  def added(%module{path: path} = node, author_id, opts) do
    parent_id = Map.fetch!(node, opts[:parent])

    module
    |> where([n], n.id in ^path)
    |> update([n],
      set: [
        descendant_count: n.descendant_count + 1,
        child_count:
          n.child_count +
            fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", n.id, type(^parent_id, Ecto.UUID)),
        recent_repliers:
          fragment(
            "(array_prepend(?, array_remove(?, ?)))[1:?]",
            type(^author_id, Ecto.UUID),
            n.recent_repliers,
            type(^author_id, Ecto.UUID),
            ^@repliers_kept
          )
      ]
    )
    |> Repo.update_all([])

    :ok
  end

  @spec removed(struct(), keyword()) :: :ok
  def removed(%{path: []}, _opts), do: :ok

  def removed(%module{path: path} = node, opts) do
    parent_id = Map.fetch!(node, opts[:parent])

    module
    |> where([n], n.id in ^path)
    |> update([n],
      set: [
        descendant_count: n.descendant_count - 1,
        child_count:
          n.child_count -
            fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", n.id, type(^parent_id, Ecto.UUID))
      ]
    )
    |> Repo.update_all([])

    :ok
  end
end
