defmodule Hearth.RateLimitTest do
  use Hearth.DataCase, async: true

  alias Hearth.Common
  alias Hearth.RateLimit
  alias Hearth.RateLimit.Bucket
  alias Hearth.TestUtils

  @minute :timer.minutes(1)

  describe "hit/3" do
    test "denies once the limit is spent" do
      key = Common.new_id()

      :ok = TestUtils.spend_rate_limit!(key, @minute, 3)

      assert {:deny, retry_after} = RateLimit.hit(key, @minute, 3)
      assert retry_after in 1..20_000
    end

    test "denies a cost bigger than the limit" do
      assert {:deny, _retry_after} = RateLimit.hit(Common.new_id(), @minute, 3, 4)
    end

    test "refills at the limit per scale" do
      key = Common.new_id()
      :ok = TestUtils.spend_rate_limit!(key, @minute, 3)

      earlier = DateTime.add(DateTime.utc_now(), -20, :second)
      :ok = TestUtils.update_rows!(Bucket, [key: key], refilled_at: earlier)

      assert {:allow, 3} = RateLimit.hit(key, @minute, 3)
      assert {:deny, _retry_after} = RateLimit.hit(key, @minute, 3)
    end

    test "keeps each key apart" do
      key = Common.new_id()
      {:allow, 1} = RateLimit.hit(key, @minute, 1)

      assert {:deny, _retry_after} = RateLimit.hit(key, @minute, 1)
      assert {:allow, 1} = RateLimit.hit(Common.new_id(), @minute, 1)
    end

    test "counts what is spent" do
      key = Common.new_id()

      assert {:allow, 1} = RateLimit.hit(key, @minute, 5)
      assert {:allow, 3} = RateLimit.hit(key, @minute, 5, 2)
    end
  end
end
