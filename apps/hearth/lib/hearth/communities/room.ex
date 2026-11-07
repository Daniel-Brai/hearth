defmodule Hearth.Communities.Room do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Communities.Community
  alias Hearth.Communities.RoomRole
  alias Hearth.Communities.RoomSettings

  # The moderation level changes through Hearth.Moderation.set_level/3, which logs it
  @fields ~w[type name topic group_id position access]a
  @changeable [:settings | @fields -- [:type]]

  schema "rooms" do
    field :type, Ecto.Enum, values: [:text, :voice], default: :text
    field :slug, :string
    field :name, :string
    field :topic, :string
    field :group_id, Ecto.UUID
    field :position, :integer, default: 0
    field :moderation, Ecto.Enum, values: Ecto.Enum.values(Community, :moderation)
    field :archived_at, :utc_datetime_usec
    field :access, Ecto.Enum, values: [:everyone, :roles], default: :everyone

    embeds_one :settings, RoomSettings, on_replace: :update

    belongs_to :community, Community
    has_many :room_roles, RoomRole

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          type: :text | :voice,
          slug: String.t(),
          name: String.t(),
          topic: nil | String.t(),
          group_id: nil | T.id(),
          position: integer(),
          moderation: nil | :full | :reports | :none,
          settings: RoomSettings.t(),
          archived_at: nil | DateTime.t(),
          access: :everyone | :roles,
          community_id: T.id(),
          room_roles: Ecto.Association.NotLoaded.t() | [RoomRole.t()]
        }

  # Who may see private rooms, the role ids someone holds and the communities where they hold room.update
  @type sight :: %{role_ids: [T.id()], managed: [T.id()]}

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = room, %{} = params) do
    room
    |> cast(params, @fields)
    |> cast_embed(:settings)
    |> default_settings()
    |> validate_required([:name])
    |> validate_length(:name, max: 40)
    |> validate_length(:topic, max: 200)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> put_slug()
    |> validate_required([:slug])
    |> unique_constraint([:community_id, :slug], error_key: :name)
  end

  defp default_settings(changeset) do
    case get_field(changeset, :settings) do
      nil -> put_embed(changeset, :settings, %RoomSettings{})
      %RoomSettings{} -> changeset
    end
  end

  defp put_slug(%Changeset{data: %{slug: nil}} = changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, Common.slugify(name))
    end
  end

  defp put_slug(changeset), do: changeset

  @spec for_community(T.id()) :: [t()]
  def for_community(community_id) do
    __MODULE__
    |> where([r], r.community_id == ^community_id and is_nil(r.archived_at))
    |> order_by([:position, :inserted_at])
    |> Repo.all()
  end

  @spec next_position(T.id(), nil | T.id()) :: non_neg_integer()
  def next_position(community_id, group_id) do
    query =
      from r in __MODULE__,
        where: r.community_id == ^community_id and is_nil(r.archived_at),
        select: coalesce(max(r.position), -1) + 1

    query |> in_group(group_id) |> Repo.one()
  end

  @spec ids_in(T.id()) :: [T.id()]
  def ids_in(community_id) do
    query =
      from r in __MODULE__,
        where: r.community_id == ^community_id and is_nil(r.archived_at),
        select: r.id

    Repo.all(query)
  end

  @spec place([T.id()], nil | T.id()) :: :ok
  def place(room_ids, group_id), do: put_places(room_ids, 0, group_id)

  @spec ungroup(T.id(), T.id()) :: :ok
  def ungroup(community_id, group_id) do
    start = next_position(community_id, nil)

    query =
      from r in __MODULE__,
        where: r.group_id == ^group_id,
        order_by: [:position, :inserted_at],
        select: r.id

    query |> Repo.all() |> put_places(start, nil)
  end

  defp put_places([], _first, _group_id), do: :ok

  defp put_places(room_ids, first, group_id) do
    positions = Enum.to_list(first..(first + length(room_ids) - 1))

    query =
      from r in __MODULE__,
        join:
          p in fragment(
            "SELECT * FROM unnest(?::uuid[], ?::int[]) AS p(id, position)",
            type(^room_ids, {:array, Ecto.UUID}),
            ^positions
          ),
        on: p.id == r.id,
        update: [set: [position: p.position, group_id: type(^group_id, Ecto.UUID)]]

    {_count, nil} = Repo.update_all(query, [])

    :ok
  end

  defp in_group(query, nil), do: where(query, [r], is_nil(r.group_id))
  defp in_group(query, group_id), do: where(query, [r], r.group_id == ^group_id)

  @spec visible_to(Ecto.Queryable.t(), sight()) :: Ecto.Query.t()
  def visible_to(query \\ __MODULE__, %{role_ids: role_ids, managed: managed}) do
    granted = from(rr in RoomRole, where: rr.role_id in ^role_ids, select: rr.room_id)

    where(
      query,
      [r],
      r.access == :everyone or r.community_id in ^managed or r.id in subquery(granted)
    )
  end

  @spec for_community(T.id(), sight()) :: [t()]
  def for_community(community_id, sight) do
    __MODULE__
    |> where([r], r.community_id == ^community_id and is_nil(r.archived_at))
    |> visible_to(sight)
    |> order_by([:position, :inserted_at])
    |> preload_roles(community_id in sight.managed)
    |> Repo.all()
  end

  defp preload_roles(query, true), do: preload(query, :room_roles)
  defp preload_roles(query, false), do: query

  @spec visible(keyword(), sight()) :: [t()]
  def visible(filters, sight) do
    filters
    |> query_from()
    |> visible_to(sight)
    |> Repo.all()
  end

  @spec visible?(t(), sight()) :: boolean()
  def visible?(%__MODULE__{id: id}, sight) do
    __MODULE__
    |> where([r], r.id == ^id)
    |> visible_to(sight)
    |> Repo.exists?()
  end

  @spec archived(T.id()) :: [t()]
  def archived(community_id) do
    __MODULE__
    |> where([r], r.community_id == ^community_id and not is_nil(r.archived_at))
    |> order_by(desc: :archived_at)
    |> preload(:room_roles)
    |> Repo.all()
  end

  @spec archive(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def archive(%__MODULE__{} = room) do
    room
    |> change(archived_at: DateTime.utc_now())
    |> Repo.update()
    |> with_roles()
  end

  @spec restore(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def restore(%__MODULE__{} = room) do
    room
    |> change(archived_at: nil)
    |> Repo.update()
    |> with_roles()
  end

  defp with_roles({:ok, room}), do: {:ok, Repo.preload(room, :room_roles)}
  defp with_roles({:error, _changeset} = error), do: error

  @spec put_moderation(t(), nil | Community.level()) ::
          {:ok, t()} | {:error, Changeset.t()}
  def put_moderation(%__MODULE__{} = room, level) do
    room
    |> change(moderation: level)
    |> Repo.update()
  end
end
