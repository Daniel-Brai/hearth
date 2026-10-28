defmodule HearthWeb.MetricsEndpointTest do
  use HearthWeb.ConnCase, async: true

  @endpoint HearthWeb.MetricsEndpoint

  describe "health" do
    test "answers liveness on metrics port", %{conn: conn} do
      assert %{"status" => "live"} = conn |> get("/healthz/live") |> json_response(200)
    end

    test "answers readiness once the database does", %{conn: conn} do
      assert %{"status" => "ready", "checks" => %{"database" => "ok"}} =
               conn |> get("/healthz/ready") |> json_response(200)
    end
  end
end
