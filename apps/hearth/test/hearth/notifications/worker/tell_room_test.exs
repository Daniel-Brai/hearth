defmodule Hearth.Notifications.Worker.TellRoomTest do
  use Hearth.DataCase, async: true

  alias Hearth.Accounts
  alias Hearth.Chat
  alias Hearth.Common
  alias Hearth.Notifications
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.Worker.TellRoom
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    room = TestUtils.get_room!(community, type: :text)
    {:ok, message} = Chat.send_message(owner, room, %{body: "Standup in five @all"})
    args = %{message_id: message.id, url: "/c/#{community.slug}/chat/#{room.slug}", told: []}

    {:ok, binding()}
  end

  describe "perform/1" do
    test "does nothing for a message already gone", %{args: args} do
      assert :ok = perform_job(TellRoom, %{args | message_id: Common.new_id()})
    end

    test "tells nobody who can't see the private room", %{owner: owner, community: community} do
      member = TestUtils.join_random_member!(community)
      room = TestUtils.create_random_private_room!(community, ["moderator"])
      {:ok, message} = Chat.send_message(owner, room, %{body: "Mods only @all"})

      assert :ok = perform_job(TellRoom, %{message_id: message.id, url: "/", told: []})

      assert %Page{data: []} = Notifications.list_notifications(member)
    end

    test "tells nobody who turned mentions off", %{args: args, member: member} do
      changes = %{notification_prefs: %{"mentions" => false}}
      {:ok, _settings} = Accounts.update_settings(member, changes)

      assert :ok = perform_job(TellRoom, args)

      assert %Page{data: []} = Notifications.list_notifications(member)
    end

    test "tells nobody named in the message twice", %{args: args, member: member} do
      assert :ok = perform_job(TellRoom, %{args | told: [member.id]})

      assert %Page{data: []} = Notifications.list_notifications(member)
    end

    test "tells everyone in the room but the sender", %{
      args: args,
      owner: owner,
      member: member
    } do
      assert :ok = perform_job(TellRoom, args)

      assert %Page{data: [%Notification{kind: :mention}]} =
               Notifications.list_notifications(member)

      assert %Page{data: []} = Notifications.list_notifications(owner)
    end
  end
end
