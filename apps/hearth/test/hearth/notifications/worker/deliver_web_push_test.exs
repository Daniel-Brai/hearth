defmodule Hearth.Notifications.Worker.DeliverWebPushTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Notifications.PushSubscription
  alias Hearth.Notifications.SealedArgs
  alias Hearth.Notifications.WebPush
  alias Hearth.Notifications.Worker.DeliverWebPush
  alias Hearth.TestUtils
  alias Plug.Conn

  setup {Req.Test, :verify_on_exit!}

  setup do
    user = TestUtils.register_random_user!()

    {:ok, subscription: TestUtils.link_random_push_sub!(user)}
  end

  describe "enqueue/3" do
    test "keeps text out of job args", %{subscription: subscription} do
      text = Lorem.sentence()

      assert {:ok, _job} = DeliverWebPush.enqueue(subscription.id, ~s({"body":"#{text}"}))
      assert [job] = all_enqueued(worker: DeliverWebPush)

      refute inspect(job.args) =~ text
      assert %{"subscription_id" => _id, "sealed" => _sealed} = job.args
    end
  end

  describe "perform/1" do
    test "ignores deleted subscription", %{subscription: subscription} do
      PushSubscription.delete(subscription)

      assert :ok =
               perform_job(DeliverWebPush, %{
                 subscription_id: subscription.id,
                 sealed: SealedArgs.seal("{}")
               })
    end

    test "deletes expired subscription", %{subscription: subscription} do
      Req.Test.expect(WebPush, &Conn.send_resp(&1, 410, ""))

      assert :ok =
               perform_job(DeliverWebPush, %{
                 subscription_id: subscription.id,
                 sealed: SealedArgs.seal("{}")
               })

      refute PushSubscription.get(id: subscription.id)
    end

    test "cancels payload that is too large", %{subscription: subscription} do
      Req.Test.expect(WebPush, &Conn.send_resp(&1, 413, ""))

      assert {:cancel, :payload_too_large} =
               perform_job(DeliverWebPush, %{
                 subscription_id: subscription.id,
                 sealed: SealedArgs.seal("{}")
               })
    end

    test "send push", %{subscription: subscription} do
      Req.Test.expect(WebPush, &Conn.send_resp(&1, 201, ""))

      args = %{
        subscription_id: subscription.id,
        sealed: SealedArgs.seal("{}"),
        options: %{urgency: "high"}
      }

      assert :ok = perform_job(DeliverWebPush, args)

      assert %PushSubscription{last_used_at: %DateTime{}} =
               PushSubscription.get(id: subscription.id)
    end
  end
end
