defmodule Hearth.Forum.Kind do
  use Hearth.Repo.Schema, prefix: "forum"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @fields ~w[key label icon hue description title_hint body_hint answers postable position]a
  @changeable @fields -- [:key]

  schema "post_kinds" do
    field :community_id, Ecto.UUID
    field :key, :string
    field :label, :string
    field :icon, :string
    field :hue, :string
    field :description, :string
    field :title_hint, :string
    field :body_hint, :string
    field :answers, :boolean, default: false
    field :postable, :boolean, default: true
    field :position, :integer, default: 0

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          community_id: T.id(),
          key: String.t(),
          label: String.t(),
          icon: String.t(),
          hue: String.t(),
          description: nil | String.t(),
          title_hint: nil | String.t(),
          body_hint: nil | String.t(),
          answers: boolean(),
          postable: boolean(),
          position: integer()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = kind, %{} = params) do
    kind
    |> cast(params, @fields)
    |> validate_required(~w[community_id key label icon hue]a)
    |> validate_length(:label, max: 30)
    |> unique_constraint([:community_id, :key], error_key: :key)
  end

  @spec for_community(T.id()) :: [t()]
  def for_community(community_id) do
    __MODULE__
    |> where(community_id: ^community_id)
    |> order_by(:position)
    |> Repo.all()
  end
end
