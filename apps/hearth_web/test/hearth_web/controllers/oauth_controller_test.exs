defmodule HearthWeb.OAuthControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Notifications

  @cookie "hearth_oauth"

  describe "start" do
    test "fails if provider is not set up", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/oauth/google", %{return_to: "/signin?invite=abc"})

      assert redirected_to(conn) ==
               Notifications.url("/signin?invite=abc") <> "#oauth_error=unavailable&via=google"

      refute conn.resp_cookies[@cookie]
    end

    test "redirects to provider", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/oauth/github?return_to=/c/early-birds")

      assert conn
             |> redirected_to()
             |> String.starts_with?("https://github.com/login/oauth/authorize")

      assert %{http_only: true, same_site: "Lax"} = conn.resp_cookies[@cookie]
    end
  end

  describe "callback" do
    test "fails without the cookie", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/oauth/github/callback?code=abc&state=xyz")

      assert redirected_to(conn) ==
               Notifications.url("/signin") <> "#oauth_error=expired&via=github"
    end

    test "fails if state does not match", %{conn: conn} do
      conn =
        conn
        |> get(~p"/api/auth/oauth/github?return_to=//evil.example")
        |> recycle()
        |> get(~p"/api/auth/oauth/github/callback?code=abc&state=wrong")

      assert redirected_to(conn) ==
               Notifications.url("/signin") <> "#oauth_error=failed&via=github"

      assert %{max_age: 0} = conn.resp_cookies[@cookie]
    end

    test "sends a backslash path back to sign in", %{conn: conn} do
      conn =
        conn
        |> get(~p"/api/auth/oauth/github?return_to=/%5Cevil.example")
        |> recycle()
        |> get(~p"/api/auth/oauth/github/callback?code=abc&state=wrong")

      assert redirected_to(conn) =~ Notifications.url("/signin") <> "#"
    end
  end
end
