defmodule Hearth.AI do
  # Speech becomes text here so Transcripts never loads a model itself

  use Boundary,
    deps: [Hearth.Common, Hearth.Media, Hearth.TranscriptionPolicy],
    exports: [Transcriber]

  alias Hearth.AI.Transcriber
  alias Hearth.AI.Whisper
  alias Hearth.TranscriptionPolicy

  @spec servings() :: [module()]
  def servings do
    case TranscriptionPolicy.on?() and Transcriber.impl() == Whisper do
      true -> [Whisper]
      false -> []
    end
  end

  @spec transcribe(Path.t()) :: {:ok, [Transcriber.segment()]} | {:error, Transcriber.error()}
  def transcribe(path) when is_binary(path), do: Transcriber.impl().transcribe(path)

  @spec model() :: String.t()
  def model, do: Transcriber.impl().model()
end
