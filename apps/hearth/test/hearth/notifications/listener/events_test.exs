defmodule Hearth.Notifications.Listener.EventsTest do
  use Hearth.DataCase, async: true

  alias Hearth.Common
  alias Hearth.Events.EventReminder
  alias Hearth.Events.EventScheduled
  alias Hearth.Notifications
  alias Hearth.Notifications.Listener.Events, as: Listener
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.Worker.TellMembers
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
  end

  test "reminds nobody who can't see the private room" do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    member = TestUtils.join_random_member!(community)
    room = TestUtils.create_random_private_room!(community, ["moderator"], type: :voice)
    event = TestUtils.create_random_community_event!(owner, community, room_id: room.id)

    reminder = %EventReminder{
      event_id: event.id,
      community_id: community.id,
      starts_at: event.starts_at,
      minutes: 10,
      user_ids: [member.id]
    }

    assert {:noreply, nil} = Listener.handle_info(reminder, nil)
    assert %Page{data: []} = Notifications.list_notifications(member)
  end

  test "reminds each interested person" do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    event = TestUtils.create_random_community_event!(owner, community)

    reminder = %EventReminder{
      event_id: event.id,
      community_id: community.id,
      starts_at: event.starts_at,
      minutes: 10,
      user_ids: [owner.id]
    }

    assert {:noreply, nil} = Listener.handle_info(reminder, nil)

    assert %Page{data: [%Notification{kind: :event_reminder}]} =
             Notifications.list_notifications(owner)
  end

  test "tells the members when the host asked" do
    event_id = Common.new_id()

    event = %EventScheduled{
      event_id: event_id,
      community_id: Common.new_id(),
      room_id: nil,
      host_id: Common.new_id(),
      notify: true
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert_enqueued(worker: TellMembers, args: %{event_id: event_id})
  end

  test "keeps quiet when the host didn't ask" do
    event = %EventScheduled{
      event_id: Common.new_id(),
      community_id: Common.new_id(),
      room_id: nil,
      host_id: Common.new_id(),
      notify: false
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    refute_enqueued(worker: TellMembers)
  end
end
