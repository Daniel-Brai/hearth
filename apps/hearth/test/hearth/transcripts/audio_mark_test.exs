defmodule Hearth.Transcripts.AudioMarkTest do
  use ExUnit.Case, async: true

  alias Hearth.Transcripts.AudioMark

  describe "silences/2" do
    test "returns nothing for steady talk" do
      segments = [%{start_ms: 0, end_ms: 4_000}, %{start_ms: 5_000, end_ms: 9_000}]

      assert [] = AudioMark.silences(segments, 10_000)
    end

    test "counts overlapping speakers as talk" do
      segments = [%{start_ms: 0, end_ms: 9_000}, %{start_ms: 2_000, end_ms: 3_000}]

      assert [] = AudioMark.silences(segments, 9_500)
    end

    test "marks gaps over two seconds" do
      segments = [%{start_ms: 3_000, end_ms: 4_000}, %{start_ms: 9_000, end_ms: 10_000}]

      assert [{0, 3_000}, {4_000, 9_000}, {10_000, 20_000}] =
               AudioMark.silences(segments, 20_000)
    end

    test "marks a session nobody spoke in" do
      assert [{0, 5_000}] = AudioMark.silences([], 5_000)
    end
  end
end
