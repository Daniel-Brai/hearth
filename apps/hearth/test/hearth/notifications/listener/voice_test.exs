defmodule Hearth.Notifications.Listener.VoiceTest do
  use Hearth.DataCase, async: true

  alias Hearth.Notifications.Listener.Voice, as: Listener
  alias Hearth.Notifications.Worker.TellLive
  alias Hearth.TestUtils
  alias Hearth.Voice.VoiceSessionStarted

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
  end

  test "tells nobody of a live discussion of a post" do
    [session_id, room_id, community_id, host_id, post_id] = TestUtils.random_ids(5)

    event = %VoiceSessionStarted{
      session_id: session_id,
      room_id: room_id,
      community_id: community_id,
      host_id: host_id,
      mode: :stage,
      topic: nil,
      post_id: post_id
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    refute_enqueued(worker: TellLive)
  end

  test "tells the community a room went live" do
    [session_id, room_id, community_id, host_id] = TestUtils.random_ids(4)

    event = %VoiceSessionStarted{
      session_id: session_id,
      room_id: room_id,
      community_id: community_id,
      host_id: host_id,
      mode: :stage,
      topic: nil,
      post_id: nil
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert_enqueued(worker: TellLive, args: %{session_id: session_id, room_id: room_id})
  end
end
