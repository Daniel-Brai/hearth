defmodule Hearth.Notifications.Channel.WebPushTest do
  use Hearth.DataCase, async: true

  alias Faker.Internet
  alias Hearth.Notifications.Anonymous
  alias Hearth.Notifications.Channel.WebPush
  alias Hearth.Notifications.Worker.DeliverWebPush
  alias Hearth.TestUtils

  defmodule PhotoReady do
    use Hearth.Notifications.Message

    alias Hearth.Notifications.WebPushMessage

    defstruct []

    @impl Hearth.Notifications.Message
    def via(%__MODULE__{}, _notifiable), do: [:web_push]

    @impl Hearth.Notifications.Message
    def to_web_push(%__MODULE__{}, _notifiable) do
      %WebPushMessage{title: "Your photo is ready", body: "It shows on your profile now."}
    end
  end

  describe "send/2" do
    test "queues nothing for an address with no devices" do
      assert :ok = WebPush.send(%PhotoReady{}, %Anonymous{email: Internet.email()})

      refute_enqueued(worker: DeliverWebPush)
    end

    test "queues push per device" do
      user = TestUtils.register_random_user!()
      phone = TestUtils.link_random_push_sub!(user)
      laptop = TestUtils.link_random_push_sub!(user)

      assert :ok = WebPush.send(%PhotoReady{}, user)

      assert_enqueued(worker: DeliverWebPush, args: %{subscription_id: phone.id})
      assert_enqueued(worker: DeliverWebPush, args: %{subscription_id: laptop.id})
    end
  end
end
