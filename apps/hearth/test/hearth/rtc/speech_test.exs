defmodule Hearth.RTC.SpeechTest do
  use ExUnit.Case, async: true

  alias Hearth.RTC.Speech
  alias Hearth.TestUtils

  setup do
    [packet, later] = TestUtils.opus_packets(2)
    speaking = %Speech{speaking?: true, loud_at: 1_000}

    {:ok, binding()}
  end

  describe "heard/3" do
    test "skips a quiet packet" do
      assert {%Speech{speaking?: false}, []} = Speech.heard(Speech.new(), 90, 1_000)
    end

    test "starts speaking on a loud packet" do
      assert {%Speech{speaking?: true, loud_at: 1_000}, events} =
               Speech.heard(Speech.new(), 30, 1_000)

      assert events == [{:speaking, true}, {:check_in, 400}]
    end

    test "counts a packet without a level as loud" do
      assert {%Speech{speaking?: true}, [{:speaking, true} | _check]} =
               Speech.heard(Speech.new(), nil, 1_000)
    end

    test "keeps speaking without telling again", %{speaking: speaking} do
      assert {%Speech{loud_at: 1_200}, []} = Speech.heard(speaking, 30, 1_200)
    end
  end

  describe "check/2" do
    test "waits out the rest of a pause", %{speaking: speaking} do
      assert {%Speech{speaking?: true}, [{:check_in, 300}]} = Speech.check(speaking, 1_100)
    end

    test "stops speaking after a long pause", %{speaking: speaking} do
      assert {%Speech{speaking?: false}, [{:speaking, false}]} = Speech.check(speaking, 1_400)
    end

    test "drops a phrase too short to caption", %{speaking: speaking, packet: packet} do
      speech = %{speaking | phrase: %{started_at: 1_000, packets: [packet]}}

      assert {%Speech{phrase: nil}, [{:speaking, false}]} = Speech.check(speech, 1_500)
    end

    test "hands over a phrase when speech stops", %{speaking: speaking, packet: packet} do
      speech = %{speaking | phrase: %{started_at: 300, packets: [packet]}}

      assert {%Speech{phrase: nil}, [{:speaking, false}, {:phrase, [^packet]}]} =
               Speech.check(speech, 1_400)
    end
  end

  describe "keep/5" do
    test "skips a packet with captions off", %{speaking: speaking, packet: packet} do
      assert {%Speech{phrase: nil}, []} = Speech.keep(speaking, false, :audio, packet, 1_000)
    end

    test "skips video", %{speaking: speaking, packet: packet} do
      assert {%Speech{phrase: nil}, []} = Speech.keep(speaking, true, :video, packet, 1_000)
    end

    test "drops a phrase when captions turn off", %{speaking: speaking, packet: packet} do
      speech = %{speaking | phrase: %{started_at: 1_000, packets: [packet]}}

      assert {%Speech{phrase: nil}, []} = Speech.keep(speech, false, :video, packet, 1_100)
    end

    test "keeps packets in order", %{speaking: speaking, packet: packet, later: later} do
      {speech, []} = Speech.keep(speaking, true, :audio, packet, 1_000)

      assert {%Speech{phrase: %{started_at: 1_000, packets: [^later, ^packet]}}, []} =
               Speech.keep(speech, true, :audio, later, 1_020)
    end

    test "hands over the longest phrase", %{speaking: speaking, packet: packet, later: later} do
      speech = %{speaking | phrase: %{started_at: 1_000, packets: [packet]}}

      assert {%Speech{phrase: nil}, [{:phrase, [^packet, ^later]}]} =
               Speech.keep(speech, true, :audio, later, 7_000)
    end
  end
end
