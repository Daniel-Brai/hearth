defmodule Hearth.Transcripts.Worker.Transcribe do
  # TranscriptionPolicy names this worker so Voice can queue it without depending on Transcripts
  # Each speaker is saved as it finishes, so a retry only redoes the ones left

  use Oban.Worker,
    queue: :transcribe,
    max_attempts: 5,
    unique: [period: :infinity, keys: [:recording_id], states: :incomplete]

  alias Hearth.AI
  alias Hearth.Media.TempFile
  alias Hearth.Storage
  alias Hearth.TranscriptionPolicy
  alias Hearth.Transcripts.Command.FailTranscript
  alias Hearth.Transcripts.Command.PublishTranscript
  alias Hearth.Transcripts.Command.SaveSpeaker
  alias Hearth.Transcripts.Command.StartTranscript
  alias Hearth.Transcripts.Speaker
  alias Hearth.Transcripts.Transcript
  alias Hearth.Voice

  # How long to wait for the model to load before asking again
  @not_ready_seconds 60

  @impl Oban.Worker
  def timeout(%Oban.Job{}), do: :timer.hours(3)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"recording_id" => id}} = job) do
    with :ok <- TranscriptionPolicy.check(),
         {:ok, recording} <- Voice.get_recording(id: id, status: :ready),
         {:ok, session} <- Voice.get_session(id: recording.session_id),
         {:ok, transcript} <- StartTranscript.execute(recording, session) do
      transcript
      |> transcribe(recording, session)
      |> settle(transcript, job)
    else
      {:error, reason} -> {:cancel, reason}
    end
  end

  defp transcribe(%Transcript{status: status}, _recording, _session)
       when status in [:ready, :failed],
       do: :done

  defp transcribe(transcript, recording, session) do
    with :ok <- transcribe_speakers(transcript, recording) do
      PublishTranscript.execute(transcript, recording, session)
    end
  end

  defp transcribe_speakers(transcript, recording) do
    recording.speakers
    |> Enum.sort_by(& &1.user_id)
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {file, index}, :ok ->
      case transcribe_speaker(transcript, file, index) do
        {:ok, _speaker} -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp transcribe_speaker(transcript, file, index) do
    {:ok, speaker} =
      Speaker.ensure(%Speaker{
        transcript_id: transcript.id,
        speaker_index: index,
        user_id: file.user_id
      })

    case speaker.transcribed_at do
      nil -> TempFile.run(&read_speaker(speaker, file.key, &1))
      _done -> {:ok, speaker}
    end
  end

  # dir comes from TempFile.run/1, made from a new id
  # sobelow_skip ["Traversal.FileModule"]
  defp read_speaker(speaker, key, dir) do
    File.mkdir_p!(dir)
    path = Path.join(dir, "speaker.m4a")

    with :ok <- Storage.download(key, path),
         {:ok, segments} <- AI.transcribe(path) do
      SaveSpeaker.execute(speaker, segments)
    end
  end

  defp settle(:done, _transcript, _job), do: :ok
  defp settle({:ok, _ready}, _transcript, _job), do: :ok
  defp settle({:error, :not_ready}, _transcript, _job), do: {:snooze, @not_ready_seconds}
  # Moved on while this ran, such as a duplicate run that finished first
  defp settle({:error, :stale}, _transcript, _job), do: :ok

  defp settle({:error, :not_found}, transcript, _job),
    do: fail(transcript, "The recording's audio is gone.", :missing)

  defp settle({:error, :unreadable}, transcript, _job),
    do: fail(transcript, "A speaker's audio couldn't be read.", :unreadable)

  defp settle({:error, reason}, transcript, %Oban.Job{attempt: attempt, max_attempts: max})
       when attempt >= max,
       do: fail(transcript, "The transcript couldn't be written.", reason)

  defp settle({:error, reason}, _transcript, _job), do: {:error, reason}

  defp fail(transcript, failure, reason) do
    _failed = FailTranscript.execute(transcript, failure)
    {:cancel, reason}
  end
end
