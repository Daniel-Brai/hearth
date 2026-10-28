defmodule Hearth.Notifications.Worker.TellLiveTest do
  use Hearth.DataCase, async: true

  alias Hearth.Accounts
  alias Hearth.Common
  alias Hearth.Notifications
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.Worker.TellLive
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    room = TestUtils.create_random_voice_room!(community)

    args = %{
      session_id: Common.new_id(),
      community_id: community.id,
      room_id: room.id,
      host_id: owner.id
    }

    {:ok, binding()}
  end

  describe "perform/1" do
    test "does nothing for a room already gone", %{args: args} do
      assert :ok = perform_job(TellLive, %{args | room_id: Common.new_id()})
    end

    test "tells nobody who turned live rooms off", %{args: args, member: member} do
      {:ok, _settings} =
        Accounts.update_settings(member, %{notification_prefs: %{"live" => false}})

      assert :ok = perform_job(TellLive, args)

      assert %Page{data: []} = Notifications.list_notifications(member)
    end

    test "tells every member but the host", %{args: args, owner: owner, member: member} do
      assert :ok = perform_job(TellLive, args)

      assert %Page{data: [%Notification{kind: :live_started, actor_id: actor_id}]} =
               Notifications.list_notifications(member)

      assert actor_id == owner.id
      assert %Page{data: []} = Notifications.list_notifications(owner)
    end
  end
end
