defmodule Hearth.Transcripts.Command.StartTranscript do
  alias Hearth.AI
  alias Hearth.Transcripts.Transcript
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Session

  @spec execute(Recording.t(), Session.t()) :: {:ok, Transcript.t()}
  def execute(%Recording{} = recording, %Session{} = session) do
    {:ok, transcript} =
      Transcript.start(%Transcript{
        recording_id: recording.id,
        session_id: session.id,
        community_id: recording.community_id,
        post_id: session.post_id,
        engine: "local",
        model_versions: %{"transcriber" => AI.model()}
      })

    case Transcript.advance(transcript, :start) do
      {:ok, transcribing} -> {:ok, transcribing}
      # Already past queued, such as a retry after a speaker failed
      {:error, _moved_on} -> {:ok, transcript}
    end
  end
end
