defmodule Hearth.Notifications.Listener.AuthTest do
  use Hearth.DataCase, async: true

  alias Faker.Company
  alias Faker.Internet
  alias Hearth.Auth.EmailChangeBlocked
  alias Hearth.Auth.EmailChangeCodeRequested
  alias Hearth.Auth.EmailChangeConfirmed
  alias Hearth.Auth.SignInCodeRequested
  alias Hearth.Auth.TransferCodeRequested
  alias Hearth.Common
  alias Hearth.Notifications.Listener.Auth, as: Listener
  alias Hearth.Notifications.Worker.DeliverMail
  alias Hearth.TestUtils

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
    refute_enqueued(worker: DeliverMail)
  end

  test "handle sign in code for new email" do
    email = Internet.email()
    event = %SignInCodeRequested{email: email, code: "042917", ttl: 15}

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert TestUtils.mail_enqueued?(%{to: [nil, email], template: "sign_in_code"})
  end

  test "handle sign in code for registered email" do
    %{id: id, email: email} = TestUtils.register_random_user!()
    event = %SignInCodeRequested{email: email, code: "042917", ttl: 15}

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert_enqueued(worker: DeliverMail, args: %{user_id: id, template: "sign_in_code"})
  end

  test "handle email change code" do
    user = TestUtils.register_random_user!()
    email = Internet.email()
    event = %EmailChangeCodeRequested{user_id: user.id, email: email, code: "042917", ttl: 15}

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert TestUtils.mail_enqueued?(%{
             to: [user.display_name, email],
             template: "email_change_code"
           })
  end

  test "handle transfer code" do
    user = TestUtils.register_random_user!()

    event = %TransferCodeRequested{
      user_id: user.id,
      email: user.email,
      community_name: Company.name(),
      code: "042917",
      ttl: 15
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert TestUtils.mail_enqueued?(%{
             to: [user.display_name, user.email],
             template: "transfer_code"
           })
  end

  test "handle email change blocked" do
    email = Internet.email()
    event = %EmailChangeBlocked{user_id: Common.new_id(), email: email}

    assert {:noreply, nil} = Listener.handle_info(event, nil)
    assert TestUtils.mail_enqueued?(%{to: [nil, email], template: "email_in_use"})
  end

  test "handle email change confirmed" do
    user = TestUtils.register_random_user!()

    event = %EmailChangeConfirmed{
      user_id: user.id,
      old_email: user.email,
      new_email: Internet.email(),
      undo_token: "undo-token",
      ttl: 10_080
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert TestUtils.mail_enqueued?(%{
             to: [user.display_name, user.email],
             template: "email_changed"
           })
  end
end
