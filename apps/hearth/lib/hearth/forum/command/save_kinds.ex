defmodule Hearth.Forum.Command.SaveKinds do
  alias Ecto.Changeset
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Forum.Kind
  alias Hearth.Forum.Post
  alias Hearth.Repo

  @discussion "discussion"

  # A kind is known by its key, which never changes. Kinds left out go and their posts move to Discussion
  @spec execute(T.id(), [map()]) ::
          {:ok, [Kind.t()]} | {:error, :keeps_discussion | :no_discussion | Changeset.t()}
  def execute(community_id, kinds) when is_binary(community_id) and is_list(kinds) do
    existing = community_id |> Kind.for_community() |> Map.new(&{&1.key, &1})
    kept = kinds |> Enum.map(& &1[:key]) |> Enum.filter(&Map.has_key?(existing, &1))
    removed = existing |> Map.drop(kept) |> Map.values()

    Repo.transact(fn ->
      with :ok <- remove(removed, existing[@discussion]) do
        save_all(community_id, kinds, existing)
      end
    end)
  end

  defp remove([], _discussion), do: :ok

  defp remove(removed, nil) do
    ids = Enum.map(removed, & &1.id)

    case Post.with_kinds?(ids) do
      true -> {:error, :no_discussion}
      false -> Kind.delete_ids(ids)
    end
  end

  defp remove(removed, %Kind{id: discussion_id}) do
    ids = Enum.map(removed, & &1.id)

    case discussion_id in ids do
      true -> {:error, :keeps_discussion}
      false -> with :ok <- Post.move_kinds(ids, discussion_id), do: Kind.delete_ids(ids)
    end
  end

  defp save_all(community_id, kinds, existing) do
    result =
      kinds
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, [], Map.keys(existing)}, &save(community_id, existing, &1, &2))

    with {:ok, saved, _taken} <- result, do: {:ok, Enum.reverse(saved)}
  end

  defp save(community_id, existing, {params, position}, {:ok, saved, taken}) do
    params = Map.put(params, :position, position)

    result =
      case existing[params[:key]] do
        %Kind{} = kind -> Kind.update(kind, params)
        nil -> insert(community_id, params, taken)
      end

    case result do
      {:ok, kind} -> {:cont, {:ok, [kind | saved], [kind.key | taken]}}
      {:error, changeset} -> {:halt, {:error, changeset}}
    end
  end

  defp insert(community_id, params, taken) do
    key = params |> Map.get(:label, "") |> Common.slugify() |> free_key(taken)
    Kind.insert(%Kind{community_id: community_id}, Map.put(params, :key, key))
  end

  # A label made only of emoji has no slug, and a taken key gets a number
  defp free_key("", taken), do: free_key("kind", taken)

  defp free_key(key, taken) do
    2
    |> Stream.iterate(&(&1 + 1))
    |> Stream.map(&"#{key}-#{&1}")
    |> then(&Stream.concat([key], &1))
    |> Enum.find(&(&1 not in taken))
  end
end
