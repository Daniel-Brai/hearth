defmodule Hearth.NotificationsTest do
  use Hearth.DataCase, async: true

  alias Faker.Company
  alias Faker.Internet
  alias Faker.Person
  alias Hearth.Accounts
  alias Hearth.Common
  alias Hearth.Notifications
  alias Hearth.Notifications.Anonymous
  alias Hearth.Notifications.MailMessage
  alias Hearth.Notifications.Notices
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.PushSubscription
  alias Hearth.Notifications.WebPushMessage
  alias Hearth.Notifications.Worker.DeliverMail
  alias Hearth.Notifications.Worker.DeliverWebPush
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  defmodule Welcome do
    use Hearth.Notifications.Message

    defstruct []

    @impl Hearth.Notifications.Message
    def via(%__MODULE__{}, _notifiable), do: [:mail, :web_push]

    @impl Hearth.Notifications.Message
    def to_mail(%__MODULE__{}, _notifiable) do
      %MailMessage{}
      |> MailMessage.greeting("Welcome")
      |> MailMessage.line("Glad you're here.")
    end

    @impl Hearth.Notifications.Message
    def to_web_push(%__MODULE__{}, _notifiable), do: %WebPushMessage{title: "Welcome"}
  end

  describe "send/2" do
    test "fails if not a message" do
      assert :error = Notifications.send(%Anonymous{email: Internet.email()}, %URI{})
    end

    test "send mail" do
      email = Internet.email()

      assert :ok = Notifications.send(%Anonymous{email: email}, %Welcome{})
      assert TestUtils.mail_enqueued?(%{to: [nil, email], subject: "Welcome"})
    end

    test "send mail and push to user" do
      %{id: id, email: email} = user = TestUtils.register_random_user!()
      subscription = TestUtils.link_random_push_sub!(user)

      assert :ok = Notifications.send(user, %Welcome{})
      assert_enqueued(worker: DeliverMail, args: %{template: "welcome", user_id: id})
      assert TestUtils.mail_enqueued?(%{to: [user.display_name, email]})
      assert_enqueued(worker: DeliverWebPush, args: %{subscription_id: subscription.id})
    end
  end

  describe "link_push_sub/2" do
    test "fails if endpoint is not https" do
      params = TestUtils.random_push_sub_params("http://#{Internet.domain_name()}/push")

      assert {:error, changeset} =
               Notifications.link_push_sub(TestUtils.register_random_user!(), params)

      assert %{endpoint: ["must be an https address"]} = errors_on(changeset)
    end

    test "fails if keys are missing" do
      assert {:error, changeset} =
               Notifications.link_push_sub(TestUtils.register_random_user!(), %{
                 endpoint: Internet.url()
               })

      assert %{p256dh: ["can't be blank"], auth: ["can't be blank"]} = errors_on(changeset)
    end

    test "link push sub" do
      user = TestUtils.register_random_user!()
      params = TestUtils.random_push_sub_params()

      assert {:ok, %PushSubscription{} = subscription} = Notifications.link_push_sub(user, params)
      assert subscription.user_id == user.id
    end

    test "moves endpoint to the new user" do
      owner = TestUtils.register_random_user!()
      %{id: id} = newcomer = TestUtils.register_random_user!()
      params = TestUtils.random_push_sub_params()

      {:ok, _subscription} = Notifications.link_push_sub(owner, params)

      assert {:ok, %PushSubscription{user_id: ^id}} =
               Notifications.link_push_sub(newcomer, params)

      assert [%PushSubscription{user_id: ^id}] = PushSubscription.all(endpoint: params.endpoint)
    end
  end

  describe "unlink_push_sub/2" do
    test "ignores unknown endpoint" do
      assert :ok =
               Notifications.unlink_push_sub(TestUtils.register_random_user!(), Internet.url())
    end

    test "unlink push sub" do
      user = TestUtils.register_random_user!()
      subscription = TestUtils.link_random_push_sub!(user)

      assert :ok = Notifications.unlink_push_sub(user, subscription.endpoint)
      refute PushSubscription.get(id: subscription.id)
    end
  end

  describe "send/2 with a notice" do
    setup do
      notice =
        Notices.invite(%{
          community_id: Common.new_id(),
          community_name: Company.name(),
          inviter_id: Common.new_id(),
          inviter_name: Person.name(),
          code: "abc"
        })

      {:ok, binding()}
    end

    test "keeps nothing if kind is off", %{notice: notice} do
      user = TestUtils.register_random_user!()

      changes = %{notification_prefs: %{"replies" => false}}
      {:ok, settings} = Accounts.update_settings(user, changes)

      assert :ok =
               Notifications.send(%{user | settings: settings}, %{notice | setting: "replies"})

      assert %Page{data: []} = Notifications.list_notifications(user)
    end
  end

  describe "mark_read/2" do
    test "leaves someone else's notification alone" do
      notification = TestUtils.create_random_notification!(TestUtils.register_random_user!())

      assert :ok = Notifications.mark_read(TestUtils.register_random_user!(), notification.id)
      assert Notification.exists?(id: notification.id, read_at: nil)
    end

    test "mark read" do
      user = TestUtils.register_random_user!()
      notification = TestUtils.create_random_notification!(user)
      _other = TestUtils.create_random_notification!(user)

      assert :ok = Notifications.mark_read(user, notification.id)
      assert Notifications.unread_count(user) == 1
    end
  end

  describe "mark_all_read/1" do
    test "mark all read" do
      user = TestUtils.register_random_user!()
      _first = TestUtils.create_random_notification!(user)
      _second = TestUtils.create_random_notification!(user)

      assert :ok = Notifications.mark_all_read(user)
      assert Notifications.unread_count(user) == 0
    end
  end

  describe "unread_count/1" do
    test "stops counting at 100" do
      user = TestUtils.register_random_user!()
      :ok = TestUtils.create_random_notifications!(user, 101)

      assert Notifications.unread_count(user) == 100
    end

    test "unread count" do
      user = TestUtils.register_random_user!()
      :ok = TestUtils.create_random_notifications!(user, 3)
      :ok = TestUtils.create_random_notifications!(user, 2, read_at: DateTime.utc_now())

      assert Notifications.unread_count(user) == 3
    end
  end

  describe "prune_read/1" do
    test "keeps unread ones however old" do
      user = TestUtils.register_random_user!()

      long_ago = TestUtils.days_ago(400)
      :ok = TestUtils.create_random_notifications!(user, 2, inserted_at: long_ago)

      assert 90 |> TestUtils.days_ago() |> Notifications.prune_read() == 0
      assert Notifications.unread_count(user) == 2
    end

    test "deletes the ones read before then" do
      user = TestUtils.register_random_user!()
      :ok = TestUtils.create_random_notifications!(user, 3, read_at: TestUtils.days_ago(91))
      :ok = TestUtils.create_random_notifications!(user, 2, read_at: TestUtils.days_ago(89))

      assert 90 |> TestUtils.days_ago() |> Notifications.prune_read() == 3
    end
  end
end
