defmodule Hearth.Voice.Recording do
  use Hearth.Repo.Schema, prefix: "voice"
  use Flop.Schema

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Voice.Recording.Speaker
  alias Hearth.Voice.Recording.Track
  alias Hearth.Voice.RecordingLifecycle
  alias Hearth.Voice.Session

  @statuses ~w[recording processing ready failed]a

  @flop_options [
    filterable: ~w[room_id community_id status]a,
    sortable: [:started_at, :id],
    default_order: %{order_by: [:started_at, :id], order_directions: [:desc, :desc]},
    default_limit: 10,
    max_limit: 50
  ]

  schema "recordings" do
    field :session_id, Ecto.UUID
    field :community_id, Ecto.UUID
    field :room_id, Ecto.UUID
    field :started_by_id, Ecto.UUID
    field :title, :string
    field :status, Ecto.Enum, values: @statuses, default: :recording
    field :failure, :string
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :has_screen, :boolean, default: false
    field :duration_ms, :integer
    field :byte_size, :integer
    field :width, :integer
    field :height, :integer
    field :video_key, :string
    field :poster_key, :string
    field :processing_ms, :integer

    embeds_many :tracks, Track, on_replace: :delete
    embeds_many :speakers, Speaker, on_replace: :delete

    timestamps()
  end

  @type status :: :recording | :processing | :ready | :failed
  @type t :: %__MODULE__{
          id: T.id(),
          session_id: T.id(),
          community_id: T.id(),
          room_id: T.id(),
          started_by_id: nil | T.id(),
          title: nil | String.t(),
          status: status(),
          failure: nil | String.t(),
          started_at: DateTime.t(),
          ended_at: nil | DateTime.t(),
          has_screen: boolean(),
          duration_ms: nil | integer(),
          byte_size: nil | integer(),
          width: nil | integer(),
          height: nil | integer(),
          video_key: nil | String.t(),
          poster_key: nil | String.t(),
          processing_ms: nil | integer(),
          tracks: [Track.t()],
          speakers: [Speaker.t()]
        }

  @type scope ::
          {:room_id | :event_id | :post_id, T.id(), T.id()}

  @spec start(struct()) :: {:ok, t()} | {:error, :already_recording}
  def start(%__MODULE__{} = recording) do
    changeset =
      recording
      |> Changeset.change(status: :recording, started_at: DateTime.utc_now())
      |> Changeset.unique_constraint(:session_id,
        name: :recordings_one_running_per_session
      )

    case Repo.insert(changeset) do
      {:ok, recording} -> {:ok, recording}
      {:error, _changeset} -> {:error, :already_recording}
    end
  end

  @spec rename(t(), String.t()) :: {:ok, t()} | {:error, Changeset.t()}
  def rename(%__MODULE__{} = recording, title) do
    recording
    |> Changeset.cast(%{title: title}, [:title])
    |> Changeset.update_change(:title, &String.trim/1)
    |> Changeset.validate_required([:title])
    |> Changeset.validate_length(:title, max: 200)
    |> Repo.update()
  end

  @spec running(T.id()) :: nil | t()
  def running(session_id), do: get(session_id: session_id, status: :recording)

  # Failed recordings show only to people who may record, who can try again
  @spec shown(boolean()) :: [status()]
  def shown(true), do: @statuses
  def shown(false), do: @statuses -- [:failed]

  @spec list(scope(), boolean()) :: [t()]
  def list({field, id, community_id}, failed?) when field in ~w[room_id event_id post_id]a do
    statuses = shown(failed?)

    query =
      from(r in __MODULE__,
        join: s in Session,
        on: s.id == r.session_id,
        where: field(s, ^field) == ^id and r.community_id == ^community_id,
        where: r.status in ^statuses,
        order_by: [desc: r.started_at],
        limit: 50
      )

    Repo.all(query)
  end

  # Only writes if the row is still at the status it was read with
  @spec advance(t(), atom(), keyword()) ::
          {:ok, t()} | {:error, :invalid_transition | :stale}
  def advance(%__MODULE__{id: id, status: status} = recording, event, changes \\ []) do
    with {:ok, next} <- RecordingLifecycle.next(recording, event) do
      query = from(r in __MODULE__, where: r.id == ^id and r.status == ^status, select: r)
      changes = [status: next, updated_at: DateTime.utc_now()] ++ changes

      case Repo.update_all(query, set: changes) do
        {1, [recording]} -> {:ok, recording}
        {0, []} -> {:error, :stale}
      end
    end
  end

  @spec put_tracks(t(), [Track.t()]) :: {:ok, t()}
  def put_tracks(%__MODULE__{} = recording, tracks) do
    recording
    |> Changeset.change()
    |> Changeset.put_embed(:tracks, tracks)
    |> Changeset.put_change(:has_screen, Enum.any?(tracks, &(&1.kind == :video)))
    |> Repo.update()
  end

  @spec prefix(t()) :: String.t()
  def prefix(%__MODULE__{id: id}), do: "recordings/#{id}"

  @spec key(t(), String.t()) :: String.t()
  def key(%__MODULE__{} = recording, name), do: "#{prefix(recording)}/#{name}"
end
