defmodule Hearth.Notifications.Worker.TellMembersTest do
  use Hearth.DataCase, async: true

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Notifications
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.Worker.TellMembers
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  describe "perform/1" do
    test "does nothing for an event already gone" do
      assert :ok = perform_job(TellMembers, %{event_id: Common.new_id()})
    end

    test "tells every member but the host" do
      owner = TestUtils.register_random_user!()
      community = TestUtils.create_random_community!(owner, template: "oss")
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)
      event = TestUtils.create_random_community_event!(owner, community)

      assert :ok = perform_job(TellMembers, %{event_id: event.id})

      assert %Page{data: [%Notification{kind: :event_scheduled, actor_id: actor_id}]} =
               Notifications.list_notifications(member)

      assert actor_id == owner.id
      assert %Page{data: []} = Notifications.list_notifications(owner)
    end
  end
end
