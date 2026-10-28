defmodule Hearth.Transcripts.Transcript do
  use Hearth.Repo.Schema, prefix: "transcripts"

  alias Hearth.Common.T
  alias Hearth.Transcripts.AudioMark
  alias Hearth.Transcripts.Segment
  alias Hearth.Transcripts.Speaker
  alias Hearth.Transcripts.TranscriptLifecycle

  @statuses ~w[queued transcribing ready failed]a

  schema "transcripts" do
    field :recording_id, Ecto.UUID
    field :session_id, Ecto.UUID
    field :community_id, Ecto.UUID
    field :post_id, Ecto.UUID
    field :status, Ecto.Enum, values: @statuses, default: :queued
    field :failure, :string
    field :language, :string
    field :engine, :string
    field :model_versions, :map, default: %{}
    field :duration_ms, :integer
    field :ready_at, :utc_datetime_usec

    has_many :speakers, Speaker, preload_order: [asc: :speaker_index]
    has_many :segments, Segment, preload_order: [asc: :start_ms]
    has_many :audio_marks, AudioMark, preload_order: [asc: :start_ms]

    timestamps()
  end

  @type status :: :queued | :transcribing | :ready | :failed
  @type t :: %__MODULE__{
          id: T.id(),
          recording_id: T.id(),
          session_id: T.id(),
          community_id: T.id(),
          post_id: nil | T.id(),
          status: status(),
          failure: nil | String.t(),
          language: nil | String.t(),
          engine: String.t(),
          model_versions: map(),
          duration_ms: nil | integer(),
          ready_at: nil | DateTime.t()
        }

  # A second run of the job finds the row the first one made
  @spec start(struct()) :: {:ok, t()}
  def start(%__MODULE__{recording_id: recording_id} = transcript) do
    {:ok, _inserted} =
      Repo.insert(transcript, on_conflict: :nothing, conflict_target: :recording_id)

    {:ok, get(recording_id: recording_id)}
  end

  # A session recorded more than once shows its latest transcript
  @spec latest(keyword()) :: nil | t()
  def latest(opts) when is_list(opts) do
    opts
    |> query_from()
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> preload(^~w[speakers segments audio_marks]a)
    |> Repo.one()
  end

  # Only writes if the row is still at the status it was read with
  @spec advance(t(), atom(), keyword()) :: {:ok, t()} | {:error, :invalid_transition | :stale}
  def advance(%__MODULE__{id: id, status: status} = transcript, event, changes \\ []) do
    with {:ok, next} <- TranscriptLifecycle.next(transcript, event) do
      query = from(t in __MODULE__, where: t.id == ^id and t.status == ^status, select: t)
      changes = [status: next, updated_at: DateTime.utc_now()] ++ changes

      case Repo.update_all(query, set: changes) do
        {1, [transcript]} -> {:ok, transcript}
        {0, []} -> {:error, :stale}
      end
    end
  end
end
