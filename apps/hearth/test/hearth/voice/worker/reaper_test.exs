defmodule Hearth.Voice.Worker.ReaperTest do
  use Hearth.DataCase, async: false

  alias Hearth.TestUtils
  alias Hearth.Voice
  alias Hearth.Voice.Session
  alias Hearth.Voice.VoiceSessionEnded
  alias Hearth.Voice.Worker.Reaper

  setup do
    :ok = TestUtils.start_voice!()
    :ok = Voice.subscribe_to_pubsub()

    community = TestUtils.create_random_community!()

    {:ok, binding()}
  end

  describe "perform/1" do
    test "keeps sessions that run", %{community: community} do
      session = TestUtils.start_random_voice_session!(community)

      assert :ok = perform_job(Reaper, %{})
      assert {:ok, %Session{ended_at: nil}} = Voice.get_session(id: session.id)
    end

    test "ends sessions whose process is gone", %{community: community} do
      %{id: id} = TestUtils.insert_random_voice_session!(community)

      assert :ok = perform_job(Reaper, %{})
      assert {:ok, %Session{ended_at: %DateTime{}}} = Voice.get_session(id: id)
      assert_receive %VoiceSessionEnded{session_id: ^id, reason: :lost}
    end
  end
end
