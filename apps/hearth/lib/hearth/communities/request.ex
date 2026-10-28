defmodule Hearth.Communities.Request do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Communities.Community
  alias Hearth.Communities.Template

  @hues ~w[ink blue violet purple pink red orange yellow green aqua]a
  @fields ~w[name tagline description hue visibility template note]a

  schema "community_requests" do
    field :name, :string
    field :tagline, :string
    field :description, :string
    field :hue, Ecto.Enum, values: @hues, default: :orange

    field :visibility, Ecto.Enum,
      values: ~w[public_indexed public invite_only private]a,
      default: :public

    field :template, :string, default: "blank"
    field :note, :string
    field :status, Ecto.Enum, values: ~w[pending approved declined]a, default: :pending
    field :decided_at, :utc_datetime_usec
    field :requester_id, Ecto.UUID
    field :decided_by_id, Ecto.UUID
    belongs_to :community, Community

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          name: String.t(),
          tagline: nil | String.t(),
          description: nil | String.t(),
          hue:
            :ink | :blue | :violet | :purple | :pink | :red | :orange | :yellow | :green | :aqua,
          visibility: :public_indexed | :public | :invite_only | :private,
          template: String.t(),
          note: nil | String.t(),
          status: :pending | :approved | :declined,
          decided_at: nil | DateTime.t(),
          requester_id: T.id(),
          decided_by_id: nil | T.id(),
          community_id: nil | T.id()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = request, %{} = params) do
    request
    |> cast(params, @fields)
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :requester_id])
    |> validate_length(:name, max: 50)
    |> validate_length(:tagline, max: 120)
    |> validate_length(:description, max: 2_000)
    |> validate_length(:note, max: 500)
    |> validate_inclusion(:template, Template.ids())
  end

  @spec decide_changeset(struct(), :approved | :declined, T.id()) :: Changeset.t()
  def decide_changeset(%__MODULE__{} = request, decision, decided_by_id) do
    change(request,
      status: decision,
      decided_by_id: decided_by_id,
      decided_at: DateTime.utc_now()
    )
  end

  @spec list(:pending | :approved | :declined) :: [t()]
  def list(status) do
    __MODULE__
    |> where(status: ^status)
    |> order_by(desc: :inserted_at)
    |> preload(:community)
    |> Repo.all()
  end

  @spec decline(t(), T.id()) :: {:ok, t()} | {:error, Changeset.t()}
  def decline(%__MODULE__{} = request, decided_by_id) do
    request
    |> decide_changeset(:declined, decided_by_id)
    |> Repo.update()
  end

  @spec approve(t(), T.id(), T.id()) :: {:ok, t()} | {:error, Changeset.t()}
  def approve(%__MODULE__{} = request, decided_by_id, community_id) do
    request
    |> decide_changeset(:approved, decided_by_id)
    |> put_change(:community_id, community_id)
    |> Repo.update()
  end
end
