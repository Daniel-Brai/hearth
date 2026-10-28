defmodule Hearth.Notifications.Worker.ScheduleDigestsTest do
  use Hearth.DataCase, async: true

  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Notifications.Worker.ScheduleDigests
  alias Hearth.Notifications.Worker.SendDigest
  alias Hearth.TestUtils

  @monday ~U[2026-10-26 07:00:00Z]
  @tuesday ~U[2026-10-27 07:00:00Z]

  describe "perform/1" do
    test "skips people who turned it off" do
      user = TestUtils.register_random_user!()
      {:ok, _user} = Accounts.update_settings(user, %{digest: :off})

      assert :ok = perform_job(ScheduleDigests, %{}, scheduled_at: @monday)
      refute_enqueued(worker: SendDigest, args: %{user_id: user.id})
    end

    test "skips weekly readers on other days" do
      user = TestUtils.register_random_user!()

      assert :ok = perform_job(ScheduleDigests, %{}, scheduled_at: @tuesday)
      refute_enqueued(worker: SendDigest, args: %{user_id: user.id})
    end

    test "skips people for whom it isn't morning yet" do
      user = TestUtils.register_random_user!()
      :ok = TestUtils.update_rows!(User, [id: user.id], timezone: "America/New_York")

      assert :ok = perform_job(ScheduleDigests, %{}, scheduled_at: @monday)
      refute_enqueued(worker: SendDigest, args: %{user_id: user.id})
    end

    test "queues weekly readers on Monday" do
      user = TestUtils.register_random_user!()
      :ok = TestUtils.update_rows!(User, [id: user.id], timezone: "Pacific/Auckland")

      assert :ok = perform_job(ScheduleDigests, %{}, scheduled_at: ~U[2026-10-25 18:00:00Z])
      assert_enqueued(worker: SendDigest, args: %{user_id: user.id})
    end

    test "queues daily readers every morning" do
      user = TestUtils.register_random_user!()
      {:ok, _user} = Accounts.update_settings(user, %{digest: :daily})

      assert :ok = perform_job(ScheduleDigests, %{}, scheduled_at: @tuesday)
      assert_enqueued(worker: SendDigest, args: %{user_id: user.id})
    end

    test "reads a time zone it doesn't know as UTC" do
      user = TestUtils.register_random_user!()
      :ok = TestUtils.update_rows!(User, [id: user.id], timezone: "Mars/Olympus")

      assert :ok = perform_job(ScheduleDigests, %{}, scheduled_at: @monday)
      assert_enqueued(worker: SendDigest, args: %{user_id: user.id})
    end
  end
end
