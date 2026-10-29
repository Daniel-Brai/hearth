defmodule Hearth.Voice.Listener.CommunitiesTest do
  use Hearth.DataCase, async: true

  alias Hearth.Communities.RoomAccessChanged
  alias Hearth.TestUtils
  alias Hearth.Voice.Listener.Communities, as: Listener

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
  end

  test "handle room access changed" do
    community = TestUtils.create_random_community!()
    event = %RoomAccessChanged{community_id: community.id}

    assert {:noreply, nil} = Listener.handle_info(event, nil)
  end
end
