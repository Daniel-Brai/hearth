defmodule Hearth.Transcripts.Command.PublishTranscript do
  import Ecto.Query, only: [from: 2]

  alias Hearth.Common
  alias Hearth.PubSub
  alias Hearth.Repo
  alias Hearth.Transcripts.AudioMark
  alias Hearth.Transcripts.Segment
  alias Hearth.Transcripts.Transcript
  alias Hearth.Transcripts.TranscriptReady
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Session

  @topic "transcripts"

  @spec execute(Transcript.t(), Recording.t(), Session.t()) ::
          {:ok, Transcript.t()} | {:error, :invalid_transition | :stale}
  def execute(%Transcript{} = transcript, %Recording{} = recording, %Session{} = session) do
    duration_ms = recording.duration_ms || 0

    result =
      Repo.transact(fn ->
        marks = marks(transcript, recording, duration_ms)

        Repo.delete_all(from(m in AudioMark, where: m.transcript_id == ^transcript.id))
        Repo.insert_all(AudioMark, marks)

        Transcript.advance(transcript, :finish,
          duration_ms: duration_ms,
          ready_at: DateTime.utc_now()
        )
      end)

    with {:ok, ready} <- result do
      PubSub.broadcast(@topic, %TranscriptReady{
        transcript_id: ready.id,
        session_id: ready.session_id,
        recording_id: ready.recording_id,
        community_id: ready.community_id,
        post_id: ready.post_id,
        event_id: session.event_id
      })

      {:ok, ready}
    end
  end

  defp marks(transcript, recording, duration_ms) do
    now = DateTime.utc_now()

    [transcript_id: transcript.id]
    |> Segment.all()
    |> AudioMark.silences(duration_ms)
    |> Enum.map(fn {start_ms, end_ms} ->
      %{
        id: Common.new_id(),
        transcript_id: transcript.id,
        recording_id: recording.id,
        kind: :silence,
        start_ms: start_ms,
        end_ms: end_ms,
        inserted_at: now,
        updated_at: now
      }
    end)
  end
end
