defmodule Hearth.Voice.Command.FailRecording do
  alias Hearth.Storage
  alias Hearth.Voice
  alias Hearth.Voice.Recording

  @spec execute(Recording.t(), String.t()) :: {:ok, Recording.t()} | {:error, term()}
  def execute(%Recording{} = recording, failure) when is_binary(failure) do
    with {:ok, recording} <- Recording.advance(recording, :fail, failure: failure) do
      _deleted = recording |> Recording.prefix() |> Storage.delete_prefix()
      Voice.broadcast_recording(recording)
      {:ok, recording}
    end
  end
end
