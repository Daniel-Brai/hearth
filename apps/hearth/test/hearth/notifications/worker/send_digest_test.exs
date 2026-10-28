defmodule Hearth.Notifications.Worker.SendDigestTest do
  use Hearth.DataCase, async: true

  alias Hearth.Accounts
  alias Hearth.Common
  alias Hearth.Notifications.Worker.DeliverMail
  alias Hearth.Notifications.Worker.SendDigest
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner)
    reader = TestUtils.join_random_member!(community)

    {:ok, binding()}
  end

  describe "perform/1" do
    test "does nothing for someone gone" do
      assert :ok = perform_job(SendDigest, %{user_id: Common.new_id()})
      refute_enqueued(worker: DeliverMail)
    end

    test "sends nothing to someone who turned it off", %{
      reader: reader,
      owner: owner,
      community: community
    } do
      _post = TestUtils.create_random_post!(owner, community)
      {:ok, _user} = Accounts.update_settings(reader, %{digest: :off})

      assert :ok = perform_job(SendDigest, %{user_id: reader.id})
      refute_enqueued(worker: DeliverMail)
    end

    test "sends nothing when nothing is new", %{reader: reader} do
      assert :ok = perform_job(SendDigest, %{user_id: reader.id})
      refute_enqueued(worker: DeliverMail)
    end

    test "sends the new posts", %{reader: reader, owner: owner, community: community} do
      post = TestUtils.create_random_post!(owner, community)

      assert :ok = perform_job(SendDigest, %{user_id: reader.id})

      assert TestUtils.mail_enqueued?(%{
               user_id: reader.id,
               subject: "1 new post in #{community.name}"
             })

      assert [job] = all_enqueued(worker: DeliverMail)
      assert DeliverMail.mail(job)["text"] =~ post.title
    end
  end
end
