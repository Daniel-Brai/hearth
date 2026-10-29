defmodule Hearth.Transcripts.Worker.TranscribeTest do
  use Hearth.DataCase, async: true

  alias Hearth.Common
  alias Hearth.Storage
  alias Hearth.TestUtils
  alias Hearth.Transcripts
  alias Hearth.Transcripts.Segment
  alias Hearth.Transcripts.Transcript
  alias Hearth.Transcripts.TranscriptReady
  alias Hearth.Transcripts.Worker.Transcribe

  setup do
    :ok = Transcripts.subscribe_to_pubsub()
    community = TestUtils.create_random_community!()
    speaker = TestUtils.join_random_member!(community)
    session = TestUtils.insert_random_voice_session!(community)

    {:ok, binding()}
  end

  describe "perform/1" do
    test "fails for a missing recording" do
      assert {:cancel, :not_found} = perform_job(Transcribe, %{recording_id: Common.new_id()})
    end

    test "waits while the model loads", %{session: session} do
      recording = TestUtils.insert_random_ready_recording!(session, [{session.host_id, "down"}])

      assert {:snooze, 60} = perform_job(Transcribe, %{recording_id: recording.id})
      assert %Transcript{status: :transcribing} = Transcript.get(recording_id: recording.id)
    end

    test "fails for unreadable audio", %{session: session} do
      recording =
        TestUtils.insert_random_ready_recording!(session, [{session.host_id, "garbled"}])

      assert {:cancel, :unreadable} = perform_job(Transcribe, %{recording_id: recording.id})

      assert %Transcript{status: :failed, failure: "A speaker's audio" <> _rest} =
               Transcript.get(recording_id: recording.id)
    end

    test "fails when the audio is gone", %{session: session} do
      recording = TestUtils.insert_random_ready_recording!(session, [{session.host_id, "0 1 a"}])
      [file] = recording.speakers
      :ok = Storage.delete(file.key)

      assert {:cancel, :missing} = perform_job(Transcribe, %{recording_id: recording.id})
    end

    test "keeps finished speakers on a retry", %{session: session, speaker: speaker} do
      speakers = [{session.host_id, "0 1000 First"}, {speaker.id, "down"}]
      recording = TestUtils.insert_random_ready_recording!(session, speakers)

      assert {:snooze, 60} = perform_job(Transcribe, %{recording_id: recording.id})

      [_host_file, file] = recording.speakers
      :ok = Storage.put(file.key, "2000 3000 Second", "audio/mp4")

      assert :ok = perform_job(Transcribe, %{recording_id: recording.id})

      assert %Transcript{segments: [%{text: "First"}, %{text: "Second"}]} =
               Transcript.latest(recording_id: recording.id)
    end

    test "transcribe recording", %{session: session, speaker: speaker} do
      speakers = [
        {session.host_id, "0 4000 Welcome everyone\n10000 12000 Any questions"},
        {speaker.id, "4500 7500 Thanks for having me"}
      ]

      recording = TestUtils.insert_random_ready_recording!(session, speakers)
      %{id: id} = recording

      assert :ok = perform_job(Transcribe, %{recording_id: id})
      assert_receive %TranscriptReady{recording_id: ^id, event_id: nil}

      transcript = Transcript.latest(recording_id: id)

      assert %Transcript{status: :ready, duration_ms: 60_000, engine: "local"} = transcript
      assert [_host, _speaker] = transcript.speakers

      assert [
               %{text: "Welcome everyone"},
               %{text: "Thanks for having me"},
               %{text: "Any questions"}
             ] = transcript.segments

      assert [%{start_ms: 7_500, end_ms: 10_000}, %{start_ms: 12_000, end_ms: 60_000}] =
               transcript.audio_marks

      assert :ok = perform_job(Transcribe, %{recording_id: id})
      assert 3 = length(Segment.all(transcript_id: transcript.id))
    end
  end
end
