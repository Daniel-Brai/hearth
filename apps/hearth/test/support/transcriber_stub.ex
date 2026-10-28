defmodule Hearth.AI.TranscriberStub do
  # Each line of the audio file is "start_ms end_ms text", and a file saying down answers not ready.
  # Real Ogg audio, as live captions write, is heard as one line

  @behaviour Hearth.AI.Transcriber

  @impl Hearth.AI.Transcriber
  def model, do: "stub"

  @impl Hearth.AI.Transcriber
  def transcribe(path) do
    case File.read!(path) do
      "OggS" <> _audio -> {:ok, [%{start_ms: 0, end_ms: 1_000, text: " Hello there "}]}
      "down" -> {:error, :not_ready}
      "garbled" -> {:error, :unreadable}
      lines -> {:ok, lines |> String.split("\n", trim: true) |> Enum.map(&segment/1)}
    end
  end

  defp segment(line) do
    [start_ms, end_ms, text] = String.split(line, " ", parts: 3)
    %{start_ms: String.to_integer(start_ms), end_ms: String.to_integer(end_ms), text: text}
  end
end
