defmodule Hearth.Communities.Category do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @fields ~w[slug name position]a

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

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = category, %{} = params) do
    category
    |> cast(params, @fields)
    |> validate_required(@fields -- [:position])
    |> unique_constraint(:slug)
  end
end
