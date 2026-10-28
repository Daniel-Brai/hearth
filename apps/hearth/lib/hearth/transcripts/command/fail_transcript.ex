defmodule Hearth.Transcripts.Command.FailTranscript do
  alias Hearth.Transcripts.Transcript

  @spec execute(Transcript.t(), String.t()) :: {:ok, Transcript.t()} | {:error, term()}
  def execute(%Transcript{} = transcript, failure) when is_binary(failure),
    do: Transcript.advance(transcript, :fail, failure: failure)
end
