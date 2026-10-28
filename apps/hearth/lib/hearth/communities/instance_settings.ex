defmodule Hearth.Communities.InstanceSettings do
  use Hearth.Repo.Schema, prefix: "communities", primary_key: {:id, :integer, autogenerate: false}

  alias Hearth.Repo

  @modes ~w[admins request anyone]a

  schema "instance_settings" do
    field :creation, Ecto.Enum, values: @modes

    timestamps()
  end

  @type t :: %__MODULE__{
          id: integer(),
          creation: :admins | :request | :anyone
        }

  @spec put_creation(atom()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def put_creation(mode) when mode in @modes do
    Repo.insert(%__MODULE__{id: 1, creation: mode},
      on_conflict: {:replace, [:creation, :updated_at]},
      conflict_target: :id
    )
  end
end
