defmodule Hearth.TranscriptionPolicyTest do
  use Hearth.DataCase, async: false

  alias Hearth.Common
  alias Hearth.TestUtils
  alias Hearth.TranscriptionPolicy

  describe "parse!/1" do
    test "fails for a mode this release doesn't know" do
      assert_raise ArgumentError, ~r/TRANSCRIPTION has hosted.*off, local/, fn ->
        TranscriptionPolicy.parse!("hosted")
      end
    end

    test "reads blank as off" do
      assert TranscriptionPolicy.parse!(nil) == :off
      assert TranscriptionPolicy.parse!("  ") == :off
    end

    test "reads a known mode in any case" do
      assert TranscriptionPolicy.parse!(" Local ") == :local
      assert TranscriptionPolicy.parse!(:off) == :off
    end
  end

  describe "check/0" do
    test "refuses while transcription is off" do
      TestUtils.put_transcription(:off)

      refute TranscriptionPolicy.on?()
      assert {:error, :transcription_off} = TranscriptionPolicy.check()
    end

    test "allows it when the instance transcribes" do
      TestUtils.put_transcription(:local)

      assert TranscriptionPolicy.on?()
      assert :ok = TranscriptionPolicy.check()
    end
  end

  describe "enqueue/1" do
    test "skips while transcription is off" do
      TestUtils.put_transcription(:off)
      recording_id = Common.new_id()

      assert :ok = TranscriptionPolicy.enqueue(recording_id)
      refute_enqueued(worker: "Hearth.Transcripts.Worker.Transcribe")
    end

    test "queue transcription" do
      TestUtils.put_transcription(:local)
      recording_id = Common.new_id()

      assert :ok = TranscriptionPolicy.enqueue(recording_id)

      assert_enqueued(
        worker: "Hearth.Transcripts.Worker.Transcribe",
        queue: :transcribe,
        args: %{recording_id: recording_id}
      )
    end
  end
end
