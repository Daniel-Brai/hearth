defmodule Hearth.Voice.Command.DeleteRecording do
  alias Hearth.Repo
  alias Hearth.Storage
  alias Hearth.Voice
  alias Hearth.Voice.Recording

  # Its transcript goes with it, since a transcript belongs to one recording
  @spec execute(Recording.t()) :: {:ok, Recording.t()} | {:error, :still_recording | term()}
  def execute(%Recording{status: :recording}), do: {:error, :still_recording}

  def execute(%Recording{} = recording) do
    with :ok <- recording |> Recording.prefix() |> Storage.delete_prefix(),
         {:ok, deleted} <- Repo.delete(recording) do
      Voice.broadcast_deleted(deleted)
      {:ok, deleted}
    end
  end
end
