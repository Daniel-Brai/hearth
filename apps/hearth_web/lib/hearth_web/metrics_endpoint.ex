defmodule HearthWeb.MetricsEndpoint do
  use Phoenix.Endpoint, otp_app: :hearth_web

  alias Plug.BasicAuth

  plug HearthWeb.Plugs.Health
  plug :authenticate
  plug PromEx.Plug, prom_ex_module: HearthWeb.PromEx
  plug :not_found

  defp authenticate(conn, _opts) do
    case Application.get_env(:hearth_web, :metrics_basic_auth) do
      [username: username, password: password] when username != "" and password != "" ->
        BasicAuth.basic_auth(conn, username: username, password: password)

      _off ->
        conn
    end
  end

  defp not_found(conn, _opts), do: conn |> send_resp(404, "") |> halt()
end
