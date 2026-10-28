defmodule Hearth.Forum.Tag do
  use Hearth.Repo.Schema, prefix: "forum"

  alias Hearth.Common.T

  schema "tags" do
    field :community_id, Ecto.UUID
    field :name, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          community_id: T.id(),
          name: String.t()
        }
end
