defmodule Hearth.AI.WhisperTest do
  use ExUnit.Case, async: false

  alias Hearth.AI.Whisper
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
    @describetag :tmp_dir

    test "fails for a file that isn't audio", %{tmp_dir: dir} do
      path = TestUtils.write_file!(dir, "not audio", "notes.m4a")

      assert {:error, :unreadable} = Whisper.transcribe(path)
    end

    test "transcribe each stretch of speech", %{tmp_dir: dir} do
      path = TestUtils.write_speech!([@short, "Sam, you had the first question."], dir)

      assert {:ok, segments} = Whisper.transcribe(path)
      assert length(segments) == 2
      assert TestUtils.spoken_text(segments) =~ "welcome everyone"
      assert TestUtils.spoken_text(segments) =~ "first question"
    end

    test "transcribe a stretch longer than one window", %{tmp_dir: dir} do
      path = TestUtils.write_speech!(@long, dir)

      assert {:ok, segments} = Whisper.transcribe(path)
      assert List.last(segments).start_ms >= 28_000
      assert TestUtils.out_of_order(segments, :start_ms) == []
      assert TestUtils.spoken_text(segments) =~ "database"
    end
  end
end
