defmodule Hearth.Notifications.Worker.TellTranscriptTest do
  use Hearth.DataCase, async: true

  alias Hearth.Common
  alias Hearth.Events
  alias Hearth.Notifications
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.Worker.TellTranscript
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    other = TestUtils.join_random_member!(community)
    _room = TestUtils.create_random_voice_room!(community)
    event = TestUtils.create_random_community_event!(owner, community)
    {:ok, :interested} = Events.toggle_interest(member, event)

    {:ok, binding()}
  end

  describe "perform/1" do
    test "does nothing for an event already gone" do
      args = %{event_id: Common.new_id(), session_id: Common.new_id()}

      assert :ok = perform_job(TellTranscript, args)
    end

    test "tells people interested in the event", %{event: event, member: member, other: other} do
      session_id = Common.new_id()

      assert :ok = perform_job(TellTranscript, %{event_id: event.id, session_id: session_id})

      assert %Page{data: [%Notification{kind: :transcript_ready, subject_id: ^session_id}]} =
               Notifications.list_notifications(member)

      assert %Page{data: []} = Notifications.list_notifications(other)
    end
  end
end
