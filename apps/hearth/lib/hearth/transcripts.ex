defmodule Hearth.Transcripts do
  # Transcripts are for members of the community, like the recordings they come from

  default = [AudioMark, Segment, Speaker, Transcript, TranscriptReady]

  exports =
    case Mix.env() do
      :test -> [Worker.Transcribe | default]
      _env -> default
    end

  use Boundary,
    deps: [
      Hearth.AI,
      Hearth.Accounts,
      Hearth.Common,
      Hearth.Communities,
      Hearth.IAM,
      Hearth.Media,
      Hearth.PubSub,
      Hearth.Repo,
      Hearth.Storage,
      Hearth.TranscriptionPolicy,
      Hearth.Voice
    ],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.PubSub
  alias Hearth.TranscriptionPolicy
  alias Hearth.Transcripts.Segment
  alias Hearth.Transcripts.Speaker
  alias Hearth.Transcripts.Transcript
  alias Hearth.Voice
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Session

  @topic "transcripts"

  @type view :: %{transcript: Transcript.t(), recording: Recording.t(), session: Session.t()}

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec get_for_session(User.t(), T.id()) :: {:ok, view()} | {:error, :forbidden | :not_found}
  def get_for_session(%User{} = user, session_id) when is_binary(session_id) do
    with :ok <- on(),
         %Transcript{} = transcript <- Transcript.latest(session_id: session_id),
         {:ok, recording} <- Voice.get_recording(user, transcript.recording_id),
         {:ok, session} <- Voice.get_session(id: session_id) do
      {:ok, %{transcript: transcript, recording: recording, session: session}}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  # Only members see it, so the post doesn't point outsiders at a page they can't open
  @spec for_post(nil | User.t(), %{
          :id => T.id(),
          :community_id => T.id(),
          optional(atom()) => any()
        }) ::
          nil | %{transcript: Transcript.t(), session: Session.t(), room_name: String.t()}
  def for_post(%User{} = user, %{id: post_id, community_id: community_id}) do
    with :ok <- on(),
         true <- IAM.member?(user, community_id) and not Communities.banned?(user, community_id),
         %Transcript{} = transcript <- Transcript.latest(post_id: post_id, status: :ready),
         {:ok, session} <- Voice.get_session(id: transcript.session_id),
         {:ok, room} <- Communities.get_room(id: session.room_id),
         true <- Communities.room_visible?(user, room) do
      %{transcript: transcript, session: session, room_name: room.name}
    else
      _hidden -> nil
    end
  end

  def for_post(nil, _post), do: nil

  # The person who said it fixes their own lines, and moderators fix anyone's
  @spec edit_segment(User.t(), T.id(), map()) ::
          {:ok, Segment.t()} | {:error, :forbidden | :not_found | Changeset.t()}
  def edit_segment(%User{} = user, segment_id, %{} = params) do
    with :ok <- on(),
         %Segment{} = segment <- Segment.get(id: segment_id),
         %Transcript{} = transcript <- Transcript.get(id: segment.transcript_id),
         {:ok, _recording} <- Voice.get_recording(user, transcript.recording_id),
         :ok <- may_edit(user, segment, transcript) do
      Segment.edit(segment, user.id, params)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @spec editable_speaker_ids(User.t(), Transcript.t()) :: MapSet.t(T.id())
  def editable_speaker_ids(%User{} = user, %Transcript{speakers: speakers} = transcript)
      when is_list(speakers) do
    speakers
    |> Enum.filter(&may_edit?(user, &1, transcript))
    |> MapSet.new(& &1.id)
  end

  @spec may_edit?(User.t(), Speaker.t(), Transcript.t()) :: boolean()
  def may_edit?(%User{id: id}, %Speaker{user_id: id}, %Transcript{}), do: true

  def may_edit?(%User{} = user, %Speaker{}, %Transcript{community_id: community_id}),
    do: IAM.can?(user, :remove, %{type: :content, community_id: community_id})

  defp may_edit(user, segment, transcript) do
    case may_edit?(user, Speaker.get(id: segment.speaker_id), transcript) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  # While transcription is off the transcripts are hidden rather than refused
  defp on do
    case TranscriptionPolicy.check() do
      :ok -> :ok
      {:error, :transcription_off} -> {:error, :not_found}
    end
  end
end
