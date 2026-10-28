defmodule Hearth.TranscriptsOffTest do
  use Hearth.DataCase, async: false

  alias Hearth.Accounts
  alias Hearth.TestUtils
  alias Hearth.Transcripts

  setup do
    community = TestUtils.create_random_community!()
    session = TestUtils.insert_random_voice_session!(community)
    transcript = TestUtils.transcribe_random_recording!(session, [{session.host_id, "0 1 Hi"}])
    {:ok, owner} = Accounts.get_user(id: community.owner_id)

    TestUtils.put_transcription(:off)

    {:ok, binding()}
  end

  describe "get_for_session/2" do
    test "hides transcripts while off", %{owner: owner, session: session} do
      assert {:error, :not_found} = Transcripts.get_for_session(owner, session.id)
    end
  end

  describe "edit_segment/3" do
    test "hides lines while off", %{owner: owner, transcript: transcript} do
      [segment] = transcript.segments

      assert {:error, :not_found} = Transcripts.edit_segment(owner, segment.id, %{text: "Hello"})
    end
  end
end
