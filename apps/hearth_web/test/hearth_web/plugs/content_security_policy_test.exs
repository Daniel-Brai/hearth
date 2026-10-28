defmodule HearthWeb.Plugs.ContentSecurityPolicyTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias HearthWeb.Plugs.ContentSecurityPolicy

  test "sends policy with matching nonce" do
    conn = conn(:get, "/")

    assert conn = ContentSecurityPolicy.call(conn, ContentSecurityPolicy.init([]))

    [policy] = get_resp_header(conn, "content-security-policy")
    nonce = conn.assigns.csp_nonce

    assert policy =~ "script-src 'self' 'nonce-#{nonce}'"
    assert policy =~ "style-src 'self' 'nonce-#{nonce}'"
    assert policy =~ "object-src 'none'"
    assert policy =~ "frame-ancestors 'none'"
  end

  test "lets pages show images from the web app" do
    conn = :get |> conn("/") |> ContentSecurityPolicy.call(ContentSecurityPolicy.init([]))

    [policy] = get_resp_header(conn, "content-security-policy")

    assert policy =~ "img-src 'self' http://localhost:5173 data: blob:"
  end

  test "makes a new nonce for every request" do
    conn = conn(:get, "/")
    opts = ContentSecurityPolicy.init([])

    assert first = ContentSecurityPolicy.call(conn, opts)
    assert second = ContentSecurityPolicy.call(conn, opts)

    refute first.assigns.csp_nonce == second.assigns.csp_nonce
  end
end
