defmodule Hearth.RateLimit.Worker.DeleteFullBucketsTest do
  use Hearth.DataCase, async: true

  alias Hearth.Common
  alias Hearth.RateLimit
  alias Hearth.RateLimit.Bucket
  alias Hearth.RateLimit.Worker.DeleteFullBuckets
  alias Hearth.TestUtils

  describe "perform/1" do
    test "keeps a bucket still refilling" do
      key = Common.new_id()
      RateLimit.hit(key, :timer.minutes(1), 3)

      assert :ok = perform_job(DeleteFullBuckets, %{})
      assert Bucket.exists?(key: key)
    end

    test "deletes a bucket that has refilled" do
      key = Common.new_id()
      RateLimit.hit(key, :timer.minutes(1), 3)
      :ok = TestUtils.update_rows!(Bucket, [key: key], expires_at: TestUtils.minutes_ago(2))

      assert :ok = perform_job(DeleteFullBuckets, %{})
      refute Bucket.exists?(key: key)
    end
  end
end
