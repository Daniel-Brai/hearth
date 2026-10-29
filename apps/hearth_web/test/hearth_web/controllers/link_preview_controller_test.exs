defmodule HearthWeb.LinkPreviewControllerTest do
  use HearthWeb.ConnCase, async: true

  import Req.Test

  alias Hearth.Media.LinkFetch
  alias Hearth.TestUtils
  alias Plug.Conn

  setup {Req.Test, :set_req_test_from_context}

  setup do
    {:ok, user: TestUtils.register_random_user!()}
  end

  describe "show" do
    test "returns 401 without signing in", %{conn: conn} do
      assert conn |> get(~p"/api/link-preview?url=https://example.com") |> valid_response(401)
    end

    test "returns 404 for an address on the private network", %{conn: conn, user: user} do
      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(user)
               |> get(~p"/api/link-preview?url=http://127.0.0.1:4000/api/instance")
               |> valid_response(404)
    end

    test "shows the page's own tags", %{conn: conn, user: user} do
      path = "/#{System.unique_integer([:positive])}"
      html = ~s(<meta property="og:title" content="Daniel-Brai - Overview">
      <meta property="og:description" content="Software Engineer">)

      stub(LinkFetch, fn %Conn{method: "GET", request_path: ^path} = conn ->
        conn |> Conn.put_resp_content_type("text/html") |> Conn.send_resp(200, html)
      end)

      response =
        conn
        |> auth_conn(user)
        |> get(~p"/api/link-preview?url=#{"http://203.0.113.7" <> path}")
        |> valid_response(200)

      assert response["title"] == "Daniel-Brai - Overview"
      assert response["description"] == "Software Engineer"
    end
  end
end
