defmodule Hearth.Notifications.Worker.PruneReadTest do
  use Hearth.DataCase, async: true

  alias Hearth.Notifications
  alias Hearth.Notifications.Worker.PruneRead
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  describe "perform/1" do
    test "keeps what was read in the last 90 days" do
      user = TestUtils.register_random_user!()
      :ok = TestUtils.create_random_notifications!(user, 1, read_at: TestUtils.days_ago(80))

      assert :ok = perform_job(PruneRead, %{})
      assert %Page{data: [_kept]} = Notifications.list_notifications(user)
    end

    test "deletes what was read longer ago" do
      user = TestUtils.register_random_user!()
      :ok = TestUtils.create_random_notifications!(user, 2, read_at: TestUtils.days_ago(100))

      assert :ok = perform_job(PruneRead, %{})
      assert %Page{data: []} = Notifications.list_notifications(user)
    end
  end
end
