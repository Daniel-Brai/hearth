defmodule HearthWeb.Plugs.ContentSecurityPolicy do
  @moduledoc "Inline style attributes stay allowed because LiveDashboard and email previews use them and they can't run code"

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    nonce = 18 |> :crypto.strong_rand_bytes() |> Base.encode64()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(nonce))
  end

  defp policy(nonce) do
    Enum.join(
      [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'nonce-#{nonce}'",
        "style-src-attr 'unsafe-inline'",
        "img-src 'self' #{web_app_origin()} data: blob:",
        "font-src 'self' data:",
        "connect-src 'self'",
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'self'",
        "frame-ancestors 'none'"
      ],
      "; "
    )
  end

  defp web_app_origin do
    %URI{scheme: scheme, host: host, port: port} =
      :hearth
      |> Application.fetch_env!(:public_url)
      |> URI.parse()

    "#{scheme}://#{host}:#{port}"
  end
end
