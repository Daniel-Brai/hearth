defmodule HearthWeb.RefreshCookie do
  import Plug.Conn

  alias Hearth.Auth

  @name "hearth_refresh"
  @max_age 60 * 24 * 60 * 60

  @spec name() :: String.t()
  def name, do: @name

  @spec start(Plug.Conn.t(), map()) :: {:ok, Plug.Conn.t()} | {:error, term()}
  def start(conn, user) do
    with {:ok, session} <- Auth.create_session(user, meta(conn)), do: {:ok, put(conn, session)}
  end

  @spec put(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put(conn, session),
    do: put_resp_cookie(conn, @name, session, [max_age: @max_age] ++ options())

  @spec delete(Plug.Conn.t()) :: Plug.Conn.t()
  def delete(conn), do: delete_resp_cookie(conn, @name, options())

  @spec fetch(Plug.Conn.t()) :: {:ok, String.t()} | {:error, :missing_refresh}
  def fetch(conn) do
    case fetch_cookies(conn).cookies do
      %{@name => session} when session != "" -> {:ok, session}
      _missing -> {:error, :missing_refresh}
    end
  end

  @spec meta(Plug.Conn.t()) :: map()
  def meta(conn) do
    %{
      ip: conn.remote_ip |> :inet.ntoa() |> to_string(),
      user_agent: conn |> get_req_header("user-agent") |> List.first()
    }
  end

  defp options do
    secure = Application.fetch_env!(:hearth_web, :secure_cookies)

    [path: "/api/auth", http_only: true, secure: secure, same_site: "Strict"]
  end
end
