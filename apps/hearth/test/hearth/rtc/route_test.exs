defmodule Hearth.RTC.RouteTest do
  use ExUnit.Case, async: true

  alias Hearth.RTC.Route
  alias Hearth.TestUtils

  setup do
    [host, sharer] = TestUtils.random_ids(2)
    route = %{send_audio: false, send_video: false, muted: false, receive: [], record: nil}
    none = %{open: [], close: [], subscribe: [], unsubscribe: []}

    {:ok, binding()}
  end

  describe "changes/3" do
    test "changes nothing when the route matches", %{route: route, host: host, none: none} do
      route = %{route | send_audio: true, receive: [{host, :audio}]}

      assert Route.changes(route, [:audio], [{host, :audio}]) == none
    end

    test "opens what the route sends", %{route: route} do
      route = %{route | send_audio: true, send_video: true}

      assert %{open: [:audio, :video], close: []} = Route.changes(route, [], [])
    end

    test "closes what the route stopped sending", %{route: route} do
      assert %{open: [], close: [:video]} = Route.changes(route, [:video], [])
    end

    test "subscribes to new sources", %{route: route, host: host, sharer: sharer} do
      route = %{route | receive: [{host, :audio}, {sharer, :video}]}

      assert %{subscribe: [{^sharer, :video}]} = Route.changes(route, [], [{host, :audio}])
    end

    test "unsubscribes from dropped sources", %{route: route, sharer: sharer} do
      assert %{unsubscribe: [{^sharer, :video}]} = Route.changes(route, [], [{sharer, :video}])
    end
  end

  describe "changed?/1" do
    test "fails for no changes", %{none: none} do
      refute Route.changed?(none)
    end

    test "passes for any change", %{none: none} do
      assert Route.changed?(%{none | close: [:audio]})
    end
  end
end
