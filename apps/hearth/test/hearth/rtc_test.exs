defmodule Hearth.RTCTest do
  use ExUnit.Case, async: false

  alias Hearth.RTC
  alias Hearth.TestUtils

  describe "available?/0" do
    test "fails without an rtc node" do
      TestUtils.put_rtc(public_ip: "203.0.113.7")

      refute RTC.available?()
    end

    test "fails without a public address" do
      :ok = :pg.join(Hearth.Roles, :rtc, self())

      refute RTC.available?()
    end

    test "available" do
      TestUtils.put_rtc(public_ip: "203.0.113.7")
      :ok = :pg.join(Hearth.Roles, :rtc, self())

      assert RTC.available?()
    end
  end

  describe "pick_node/0" do
    test "gives nil without an rtc node" do
      assert nil == RTC.pick_node()
    end

    test "picks this node when it runs rtc" do
      :ok = :pg.join(Hearth.Roles, :rtc, self())

      assert node() == RTC.pick_node()
    end
  end

  describe "config/0" do
    test "reads the address and port range" do
      TestUtils.put_rtc(public_ip: " 203.0.113.7 ", port_range: "50000-50009")

      assert [public_ip: {203, 0, 113, 7}, port_range: 50_000..50_009] =
               Keyword.take(RTC.config(), [:public_ip, :port_range])
    end
  end
end
