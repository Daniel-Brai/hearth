defmodule HearthWeb.Plugs.HealthTest do
  use HearthWeb.ConnCase, async: true

  describe "live" do
    test "answers while the node runs", %{conn: conn} do
      conn = get(conn, "/healthz/live")

      assert %{"status" => "live", "version" => _version} = json_response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end
  end

  describe "ready" do
    test "answers once the database does", %{conn: conn} do
      assert %{"status" => "ready", "checks" => %{"database" => "ok"}} =
               conn |> get("/healthz/ready") |> json_response(200)
    end
  end

  test "leaves other methods to the router", %{conn: conn} do
    assert conn |> post("/healthz/live") |> response(404)
  end
end
