defmodule Hearth.Communities.Category do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @fields ~w[slug name position]a
  @slugs ~w[hobbies games art music books sports local learning work support tech]

  schema "categories" do
    field :slug, :string
    field :name, :string
    field :position, :integer, default: 0

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          slug: String.t(),
          name: String.t(),
          position: integer()
        }

  @spec slugs() :: [String.t()]
  def slugs, do: @slugs

  # In the order the slugs were given, leaving out ones that don't exist
  @spec by_slugs([String.t()]) :: [t()]
  def by_slugs(slugs) when is_list(slugs) do
    found = [slug: slugs] |> all() |> Map.new(&{&1.slug, &1})

    slugs
    |> Enum.map(&found[&1])
    |> Enum.reject(&is_nil/1)
  end

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = category, %{} = params) do
    category
    |> cast(params, @fields)
    |> validate_required(@fields -- [:position])
    |> unique_constraint(:slug)
  end
end
