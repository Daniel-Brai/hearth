defmodule Hearth.Notifications.Listener.CommunitiesTest do
  use Hearth.DataCase, async: true

  alias Faker.Company
  alias Faker.Internet
  alias Faker.Person
  alias Hearth.Common
  alias Hearth.Communities.InvitesEmailed
  alias Hearth.Notifications
  alias Hearth.Notifications.Listener.Communities, as: Listener
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.Worker.DeliverMail
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
    refute_enqueued(worker: DeliverMail)
  end

  test "handle invites emailed" do
    email = Internet.email()
    user = TestUtils.register_random_user!()
    inviter = TestUtils.register_random_user!()

    event = %InvitesEmailed{
      community_id: Common.new_id(),
      community_name: Company.name(),
      inviter_id: inviter.id,
      inviter_name: Person.name(),
      note: nil,
      invites: [%{email: email, code: "abc"}, %{email: user.email, code: "def"}]
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert TestUtils.mail_enqueued?(%{to: [nil, email], template: "community_invite"})
    assert_enqueued(worker: DeliverMail, args: %{user_id: user.id, template: "community_invite"})

    assert %Page{data: [%Notification{kind: :invite}]} =
             Notifications.list_notifications(user)
  end
end
