defmodule Hearth.AI.WhisperTest do
  use ExUnit.Case, async: false

  alias Hearth.AI.Whisper
  alias Hearth.Media.TempFile
  alias Hearth.TestUtils

  @moduletag :models
  @moduletag timeout: :timer.minutes(30)

  @short "Welcome everyone. Today we are talking about supervisors and restarts."

  @long String.duplicate(
          "The supervisor restarts the worker when it crashes, and the state comes back from the database. ",
          6
        )

  setup_all do
    serving = Whisper.serving(Whisper.model(), 1)
    start_supervised!({Nx.Serving, serving: serving, name: Whisper, batch_size: 1})

    :ok
  end

  describe "transcribe/1" do
    test "fails for a file that isn't audio" do
      TempFile.run(fn dir ->
        File.mkdir_p!(dir)
        path = Path.join(dir, "notes.m4a")
        File.write!(path, "not audio")

        assert {:error, :unreadable} = Whisper.transcribe(path)
      end)
    end

    test "transcribe each stretch of speech" do
      TempFile.run(fn dir ->
        path = TestUtils.write_speech!([@short, "Sam, you had the first question."], dir)

        assert {:ok, [welcome, question]} = Whisper.transcribe(path)

        assert String.downcase(welcome.text) =~ "welcome everyone"
        assert String.downcase(question.text) =~ "first question"
        assert welcome.end_ms <= question.start_ms
      end)
    end

    test "transcribe a stretch longer than one window" do
      TempFile.run(fn dir ->
        path = TestUtils.write_speech!(@long, dir)

        assert {:ok, segments} = Whisper.transcribe(path)

        assert %{start_ms: last_start} = List.last(segments)
        assert last_start >= 28_000
        assert TestUtils.out_of_order(segments, :start_ms) == []
        assert TestUtils.spoken_text(segments) =~ "database"
      end)
    end
  end
end
