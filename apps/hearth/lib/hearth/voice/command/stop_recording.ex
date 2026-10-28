defmodule Hearth.Voice.Command.StopRecording do
  alias Hearth.Common.T
  alias Hearth.Repo
  alias Hearth.Voice.Command.StartRecording
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Worker.AssembleRecording

  @type reason :: :stopped | :ended | :lost

  @spec execute(Recording.t(), T.id(), reason()) ::
          {:ok, Recording.t()} | {:error, :invalid_transition | :stale}
  def execute(%Recording{} = recording, actor_id, reason) do
    Repo.transact(fn ->
      with {:ok, recording} <-
             Recording.advance(recording, :stop, ended_at: DateTime.utc_now()),
           {:ok, _action} <-
             StartRecording.log(recording, actor_id, :recording_stopped, %{reason: reason}),
           {:ok, _job} <- recording.id |> AssembleRecording.job() |> Oban.insert() do
        {:ok, recording}
      end
    end)
  end
end
