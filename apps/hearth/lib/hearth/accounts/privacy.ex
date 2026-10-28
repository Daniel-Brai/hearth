defmodule Hearth.Accounts.Privacy do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset

  @audiences ~w[everyone members nobody]a
  @fields ~w[show_name show_communities presence last_seen avatar]a

  @primary_key false

  embedded_schema do
    field :show_name, :boolean, default: true
    field :show_communities, Ecto.Enum, values: ~w[common everyone nobody]a, default: :common
    field :presence, Ecto.Enum, values: @audiences, default: :everyone
    field :last_seen, Ecto.Enum, values: @audiences, default: :everyone
    field :avatar, Ecto.Enum, values: @audiences, default: :everyone
  end

  @type t :: %__MODULE__{
          show_name: boolean(),
          show_communities: :common | :everyone | :nobody,
          presence: :everyone | :members | :nobody,
          last_seen: :everyone | :members | :nobody,
          avatar: :everyone | :members | :nobody
        }

  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = privacy, %{} = params) do
    privacy
    |> cast(params, @fields)
    |> validate_required(@fields)
  end
end
