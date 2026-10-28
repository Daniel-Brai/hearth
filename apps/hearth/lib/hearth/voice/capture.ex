defmodule Hearth.Voice.Capture do
  # Files upload in the background so the session goes on at once

  alias Hearth.Common.T
  alias Hearth.RTC.Peer
  alias Hearth.RTC.Recorder
  alias Hearth.Storage
  alias Hearth.Voice
  alias Hearth.Voice.Command.FailRecording
  alias Hearth.Voice.Command.StopRecording
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Recording.Track

  require Logger

  @spec route(nil | Recording.t()) :: nil | Recorder.recording()
  def route(nil), do: nil

  def route(%Recording{} = recording),
    do: %{id: recording.id, t0: DateTime.to_unix(recording.started_at, :millisecond)}

  # The peers must already have been sent routes without this recording
  @spec stop(Recording.t(), T.id(), StopRecording.reason(), [pid()]) ::
          {:ok, Recording.t()} | {:error, term()}
  def stop(%Recording{} = recording, actor_id, reason, peers) do
    Enum.each(peers, &flush/1)

    with {:ok, recording} <- StopRecording.execute(recording, actor_id, reason) do
      Voice.broadcast_recording(recording)

      {:ok, _task} =
        Task.Supervisor.start_child(Hearth.Voice.TaskSupervisor, __MODULE__, :upload, [recording])

      {:ok, recording}
    end
  end

  defp flush(peer) do
    Peer.flush(peer)
  catch
    :exit, _gone -> :ok
  end

  @doc false
  @spec upload(Recording.t()) :: {:ok, Recording.t()} | {:error, term()}
  # The recorder names its folder from the recording's id
  # sobelow_skip ["Traversal.FileModule"]
  def upload(%Recording{} = recording) do
    dir = Recorder.dir(recording.id)

    result =
      case Recorder.stretches(dir) do
        [] -> FailRecording.execute(recording, "Nothing was recorded.")
        stretches -> store(recording, stretches)
      end

    File.rm_rf(dir)
    result
  end

  defp store(recording, stretches) do
    tracks =
      stretches
      |> Enum.with_index()
      |> Enum.map(fn {stretch, n} ->
        key = Recording.key(recording, "raw/#{n}.#{stretch.kind}.rtp")
        :ok = Storage.upload_file(key, stretch.path, "application/octet-stream")

        %Track{
          user_id: stretch.user_id,
          kind: stretch.kind,
          key: key,
          offset_ms: stretch.offset_ms,
          duration_ms: stretch.duration_ms
        }
      end)

    Recording.put_tracks(recording, tracks)
  rescue
    error in MatchError ->
      Logger.error("Voice recording upload failed: #{inspect(error.term)}")
      FailRecording.execute(recording, "The recording couldn't be saved.")
  end
end
