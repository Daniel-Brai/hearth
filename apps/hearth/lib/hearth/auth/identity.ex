defmodule Hearth.Auth.Identity do
  use Hearth.Repo.Schema, prefix: "auth"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @fields ~w[user_id provider provider_uid email]a
  @providers [:github, :google]

  schema "user_identities" do
    field :user_id, Ecto.UUID
    field :provider, Ecto.Enum, values: @providers
    field :provider_uid, :string
    field :email, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          user_id: T.id(),
          provider: :github | :google,
          provider_uid: String.t(),
          email: nil | String.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = identity, %{} = params) do
    identity
    |> cast(params, @fields)
    |> validate_required(@fields -- [:email])
    |> unique_constraint([:provider, :provider_uid])
    |> unique_constraint([:user_id, :provider])
  end
end
