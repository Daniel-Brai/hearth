defmodule Hearth.Notifications.Channel.InAppTest do
  use Hearth.DataCase, async: true

  alias Faker.Internet
  alias Hearth.Common
  alias Hearth.Notifications
  alias Hearth.Notifications.Anonymous
  alias Hearth.Notifications.Channel.InApp
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.NotificationCreated
  alias Hearth.TestUtils

  defmodule Answered do
    use Hearth.Notifications.Message

    alias Hearth.Notifications.InAppMessage

    defstruct [:post_id]

    @impl Hearth.Notifications.Message
    def via(%__MODULE__{}, _notifiable), do: [:in_app]

    @impl Hearth.Notifications.Message
    def to_in_app(%__MODULE__{post_id: post_id}, _notifiable) do
      %InAppMessage{
        kind: :answer,
        subject_type: "post",
        subject_id: post_id,
        data: %{post_id: post_id}
      }
    end
  end

  setup do
    :ok = Notifications.subscribe_to_pubsub()

    {:ok, message: %Answered{post_id: Common.new_id()}}
  end

  describe "send/2" do
    test "keeps nothing for someone without an account", %{message: message} do
      assert :ok = InApp.send(message, %Anonymous{email: Internet.email()})

      refute Notification.exists?(subject_id: message.post_id)
    end

    test "keeps notification and tells apps", %{message: message} do
      %{id: user_id} = user = TestUtils.register_random_user!()

      assert :ok = InApp.send(message, user)

      assert_receive %NotificationCreated{user_id: ^user_id, kind: :answer}

      assert Notification.exists?(user_id: user_id)
    end
  end
end
