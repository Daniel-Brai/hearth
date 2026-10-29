defmodule Hearth.Voice.Worker.AssembleRecordingTest do
  use Hearth.DataCase, async: true

  alias Hearth.Media.TempFile
  alias Hearth.Media.Video
  alias Hearth.Storage
  alias Hearth.TestUtils
  alias Hearth.Voice
  alias Hearth.Voice.Command.StartRecording
  alias Hearth.Voice.Command.StopRecording
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Recording.Speaker
  alias Hearth.Voice.VoiceRecordingChanged
  alias Hearth.Voice.Worker.AssembleRecording

  setup do
    :ok = Voice.subscribe_to_pubsub()
    community = TestUtils.create_random_community!()
    speaker = TestUtils.join_random_member!(community)
    session = TestUtils.insert_random_voice_session!(community)

    {:ok, binding()}
  end

  describe "perform/1" do
    test "fails once the tracks never came", %{session: session} do
      {:ok, started} = StartRecording.execute(session, session.host_id)
      {:ok, recording} = StopRecording.execute(started, session.host_id, :stopped)

      :ok =
        TestUtils.update_rows!(Recording, [id: recording.id], ended_at: TestUtils.minutes_ago(11))

      assert {:cancel, :no_tracks} = perform_job(AssembleRecording, %{recording_id: recording.id})
      assert %Recording{status: :failed} = Recording.get(id: recording.id)
    end

    test "fails when nobody spoke", %{session: session} do
      recording = TestUtils.record_random_session!(session, [{session.host_id, :video, 0, 1}], 2)

      assert {:cancel, :silent} = perform_job(AssembleRecording, %{recording_id: recording.id})

      assert %Recording{status: :failed, failure: "Nobody spoke" <> _rest} =
               Recording.get(id: recording.id)
    end

    test "fails when the files are gone", %{session: session} do
      recording = TestUtils.record_random_session!(session, [{session.host_id, :audio, 0, 1}], 2)
      :ok = recording |> Recording.prefix() |> Storage.delete_prefix()

      assert {:cancel, :missing} = perform_job(AssembleRecording, %{recording_id: recording.id})
    end

    test "waits for the tracks", %{session: session} do
      {:ok, started} = StartRecording.execute(session, session.host_id)
      {:ok, recording} = StopRecording.execute(started, session.host_id, :stopped)

      assert {:snooze, 5} = perform_job(AssembleRecording, %{recording_id: recording.id})
    end

    test "assemble recording", %{session: session, speaker: speaker} do
      %{host_id: host_id} = session
      %{id: speaker_id} = speaker

      tracks = [
        {host_id, :audio, 0, 3},
        {speaker_id, :audio, 1_500, 2},
        {host_id, :video, 1_000, 2}
      ]

      recording = TestUtils.record_random_session!(session, tracks, 4)
      %{id: id} = recording

      assert :ok = perform_job(AssembleRecording, %{recording_id: id})
      assert_receive %VoiceRecordingChanged{recording_id: ^id, status: :ready}
      assert_enqueued(worker: "Hearth.Transcripts.Worker.Transcribe", args: %{recording_id: id})

      ready = Recording.get(id: id)

      assert %Recording{status: :ready, has_screen: true, width: 1_280, height: 720} = ready
      assert ready.duration_ms in 3_900..4_100
      assert ready.processing_ms > 0
      assert [%Speaker{}, %Speaker{}] = ready.speakers

      assert ready.speakers |> TestUtils.pluck(:user_id) |> MapSet.new() ==
               MapSet.new([host_id, speaker_id])

      assert TestUtils.stored(ready.tracks) == []

      assert {:ok, %{video_codec: "h264", audio_codec: "aac", width: 1_280, height: 720}} =
               TempFile.run(fn path ->
                 :ok = Storage.download(ready.video_key, path)
                 Video.probe(path)
               end)
    end
  end
end
