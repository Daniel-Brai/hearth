defmodule Hearth.Communities.CommunityCategory do
  use Hearth.Repo.Schema, prefix: "communities", primary_key: false

  alias Hearth.Common.T
  alias Hearth.Communities.Category
  alias Hearth.Communities.Community

  @max 2

  schema "community_categories" do
    belongs_to :community, Community, primary_key: true
    belongs_to :category, Category, primary_key: true
    field :position, :integer, default: 0
  end

  @type t :: %__MODULE__{community_id: T.id(), category_id: T.id(), position: integer()}

  # Nil leaves them as they are, so a rename keeps the categories
  @spec put(Community.t(), nil | [String.t()]) ::
          :ok | {:error, :too_many_categories | :unknown_category}
  def put(%Community{}, nil), do: :ok
  def put(%Community{}, slugs) when length(slugs) > @max, do: {:error, :too_many_categories}

  def put(%Community{id: id}, slugs) when is_list(slugs) do
    slugs = Enum.uniq(slugs)
    categories = Category.by_slugs(slugs)

    case length(categories) == length(slugs) do
      true -> replace(id, categories)
      false -> {:error, :unknown_category}
    end
  end

  @spec slugs_by_community([T.id()]) :: %{T.id() => [String.t()]}
  def slugs_by_community(community_ids) when is_list(community_ids) do
    __MODULE__
    |> join(:inner, [cc], c in assoc(cc, :category))
    |> where([cc], cc.community_id in ^community_ids)
    |> order_by([cc], [cc.community_id, cc.position])
    |> select([cc, c], {cc.community_id, c.slug})
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp replace(community_id, categories) do
    __MODULE__
    |> where([cc], cc.community_id == ^community_id)
    |> Repo.delete_all()

    rows =
      categories
      |> Enum.with_index()
      |> Enum.map(fn {category, position} ->
        %{community_id: community_id, category_id: category.id, position: position}
      end)

    {_count, nil} = Repo.insert_all(__MODULE__, rows)
    :ok
  end
end
