defmodule Hearth.Communities.Community do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common
  alias Hearth.Common.Link
  alias Hearth.Common.T
  alias Hearth.Communities.Room
  alias Hearth.Communities.Template

  @hues ~w[ink blue violet purple pink red orange yellow green aqua]a
  @visibilities ~w[public_indexed public invite_only private]a
  @levels ~w[full reports none]a
  @profile ~w[name tagline description hue logo_id banner_id welcome_message]a
  # The moderation level changes through Hearth.Moderation.set_level/3, which logs it
  @changeable [:visibility, :links | @profile]

  schema "communities" do
    field :slug, :string
    field :name, :string
    field :tagline, :string
    field :description, :string
    field :hue, Ecto.Enum, values: @hues, default: :orange
    field :logo_id, Ecto.UUID
    field :banner_id, Ecto.UUID
    field :visibility, Ecto.Enum, values: @visibilities, default: :public
    field :moderation, Ecto.Enum, values: @levels, default: :none
    field :welcome_message, :string
    field :template, :string, default: "blank"
    field :owner_id, Ecto.UUID
    field :creator_id, Ecto.UUID
    field :archived_at, :utc_datetime_usec

    has_many :rooms, Room, preload_order: [asc: :position]
    embeds_many :links, Link, on_replace: :delete

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          slug: String.t(),
          name: String.t(),
          tagline: nil | String.t(),
          description: nil | String.t(),
          hue:
            :ink | :blue | :violet | :purple | :pink | :red | :orange | :yellow | :green | :aqua,
          logo_id: nil | T.id(),
          banner_id: nil | T.id(),
          visibility: :public_indexed | :public | :invite_only | :private,
          moderation: level(),
          welcome_message: nil | String.t(),
          template: String.t(),
          owner_id: T.id(),
          creator_id: nil | T.id(),
          archived_at: nil | DateTime.t(),
          links: [Link.t()]
        }

  @type level :: :full | :reports | :none

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = community, %{} = params) do
    params = Link.unique(params)

    community
    |> cast(params, [:template, :visibility, :moderation | @profile])
    |> cast_embed(:links, with: &Link.changeset/2)
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, max: 50)
    |> validate_length(:tagline, max: 120)
    |> validate_length(:description, max: 2_000)
    |> validate_length(:welcome_message, max: 1_000)
    |> validate_inclusion(:template, Template.ids())
    |> put_slug()
    |> unique_constraint(:slug)
  end

  # The slug is made once so links keep working when the name changes
  defp put_slug(%Changeset{data: %{slug: nil}} = changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, free_slug(name))
    end
  end

  defp put_slug(changeset), do: changeset

  # Names can repeat so a taken slug gets the next number, and one with no Latin letters starts from community
  @spec free_slug(String.t()) :: T.slug()
  def free_slug(name) when is_binary(name) do
    base =
      case Common.slugify(name) do
        "" -> "community"
        slug -> slug
      end

    taken =
      __MODULE__
      |> where([c], c.slug == ^base or like(c.slug, ^"#{base}-%"))
      |> select([c], c.slug)
      |> Repo.all()
      |> MapSet.new()

    # One more than the taken ones is always enough to find a free one
    candidates = [base | Enum.map(2..(MapSet.size(taken) + 2)//1, &numbered(base, &1))]

    Enum.find(candidates, &(not MapSet.member?(taken, &1)))
  end

  # Leaves room for the number within the 60 characters a slug may have
  defp numbered(base, n),
    do: base |> String.slice(0, 55) |> String.trim_trailing("-") |> Kernel.<>("-#{n}")

  @spec owned_count(T.id()) :: non_neg_integer()
  def owned_count(owner_id) do
    __MODULE__
    |> where(owner_id: ^owner_id)
    |> Repo.aggregate(:count)
  end

  @spec transfer(t(), T.id()) :: {:ok, t()} | {:error, Changeset.t()}
  def transfer(%__MODULE__{} = community, owner_id) do
    community
    |> change(owner_id: owner_id)
    |> Repo.update()
  end

  @spec joined([T.id()]) :: [t()]
  def joined(ids) when is_list(ids) do
    query =
      from c in __MODULE__,
        where: c.id in ^ids and is_nil(c.archived_at),
        order_by: [asc: c.name],
        preload: [:rooms]

    Repo.all(query)
  end

  @spec readable_ids([T.id()]) :: [T.id()]
  def readable_ids(member_ids) when is_list(member_ids) do
    query =
      from c in __MODULE__,
        where: is_nil(c.archived_at),
        where: c.visibility in [:public_indexed, :public] or c.id in ^member_ids,
        order_by: [asc: c.id],
        select: c.id

    Repo.all(query)
  end

  @spec public() :: [t()]
  def public do
    query =
      from c in __MODULE__,
        where: c.visibility in [:public_indexed, :public] and is_nil(c.archived_at),
        order_by: [asc: c.name],
        preload: [:rooms]

    Repo.all(query)
  end

  @spec indexed() :: [t()]
  def indexed do
    __MODULE__
    |> where([c], c.visibility == :public_indexed and is_nil(c.archived_at))
    |> order_by(asc: :slug)
    |> Repo.all()
  end

  @spec put_moderation(t(), level()) :: {:ok, t()} | {:error, Changeset.t()}
  def put_moderation(%__MODULE__{} = community, level) do
    community
    |> change(moderation: level)
    |> Repo.update()
  end
end
