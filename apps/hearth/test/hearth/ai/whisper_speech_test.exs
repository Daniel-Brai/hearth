defmodule Hearth.AI.WhisperSpeechTest do
  use ExUnit.Case, async: true

  alias Hearth.AI.Whisper

  describe "speech/2" do
    test "drops blips too short to be words" do
      assert [] = Whisper.speech([{0, 1_000}, {1_200, 5_000}], 5_000)
    end

    test "returns speech between silences" do
      silences = [{0, 2_000}, {5_000, 7_000}, {9_000, nil}]

      assert [{2_000, 5_000}, {7_000, 9_000}] = Whisper.speech(silences, 20_000)
    end

    test "cuts long stretches to fit the window" do
      assert [{0, 28_000}, {28_000, 56_000}, {56_000, 60_000}] = Whisper.speech([], 60_000)
    end
  end
end
