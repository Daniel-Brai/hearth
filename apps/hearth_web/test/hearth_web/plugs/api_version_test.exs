defmodule HearthWeb.Plugs.ApiVersionTest do
  use HearthWeb.ConnCase, async: true

  alias HearthWeb.Plugs.ApiVersion

  describe "call/2" do
    test "fails for an unknown version", %{conn: conn} do
      assert %{"code" => "unsupported_version"} =
               conn
               |> put_req_header("hearth-version", "2001-01-01")
               |> get(~p"/api/instance")
               |> json_response(400)
    end

    test "uses oldest version if none sent" do
      conn = get(build_conn(), ~p"/api/instance")

      assert get_resp_header(conn, "hearth-version") == [hd(ApiVersion.versions())]
    end

    test "answers with the version sent", %{conn: conn} do
      conn = get(conn, ~p"/api/instance")

      assert get_resp_header(conn, "hearth-version") == [ApiVersion.latest()]
      assert conn.assigns.api_version == ApiVersion.latest()
    end
  end
end
