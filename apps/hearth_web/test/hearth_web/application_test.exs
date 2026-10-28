defmodule HearthWeb.ApplicationTest do
  use ExUnit.Case, async: true

  alias Hearth.TestUtils

  describe "children/1" do
    test "runs no public endpoint on a node without web" do
      children = HearthWeb.Application.children([:media, :ai])

      refute HearthWeb.Endpoint in children

      assert TestUtils.child_names(children) == [
               HearthWeb.PromEx,
               HearthWeb.Telemetry,
               HearthWeb.MetricsEndpoint,
               HearthWeb.Broadcaster
             ]
    end

    test "web node starts web parts" do
      children = HearthWeb.Application.children([:web])

      assert TestUtils.child_names(children) == [
               HearthWeb.PromEx,
               HearthWeb.Telemetry,
               HearthWeb.FloodGuard,
               HearthWeb.Presence,
               HearthWeb.Endpoint,
               HearthWeb.MetricsEndpoint,
               HearthWeb.Broadcaster
             ]
    end
  end
end
