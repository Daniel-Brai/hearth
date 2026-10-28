defmodule Hearth.Forum.Draft do
  use Hearth.Repo.Schema, prefix: "forum"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Forum.Kind

  @changeable ~w[title body kind_id]a

  schema "drafts" do
    field :user_id, Ecto.UUID
    field :community_id, Ecto.UUID
    belongs_to :kind, Kind
    field :title, :string
    field :body, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          user_id: T.id(),
          community_id: T.id(),
          kind_id: nil | T.id(),
          title: nil | String.t(),
          body: nil | String.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = draft, %{} = params) do
    draft
    |> cast(params, @changeable)
    |> validate_length(:title, max: 150)
    |> validate_length(:body, max: 40_000)
  end
end
