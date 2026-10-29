defmodule Hearth.Voice.CaptionsTest do
  use Hearth.DataCase, async: false

  alias Hearth.Common
  alias Hearth.TestUtils
  alias Hearth.Voice
  alias Hearth.Voice.Captions
  alias Hearth.Voice.VoiceCaption

  setup do
    :ok = TestUtils.start_voice!()
    :ok = Voice.subscribe_to_pubsub()

    {:ok, session_id: Common.new_id(), user_id: Common.new_id()}
  end

  describe "caption/3" do
    test "skips a stretch at the limit", %{session_id: s, user_id: u} do
      TestUtils.put_voice(caption_limit: 0)

      assert :busy = Captions.caption(s, u, TestUtils.opus_packets(25))
      refute_receive %VoiceCaption{session_id: ^s}, 200
    end

    test "sends what was said to the room", %{session_id: s, user_id: u} do
      assert :ok = Captions.caption(s, u, TestUtils.opus_packets(25))

      assert_receive %VoiceCaption{session_id: ^s, user_id: ^u, text: "Hello there"}, 2_000
    end
  end
end
