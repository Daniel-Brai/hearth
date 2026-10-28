defmodule HearthWeb.Plugs.Health do
  @moduledoc "Live checks nothing else so a slow database never gets a healthy node restarted"

  @behaviour Plug

  import Plug.Conn

  alias Hearth.Instance

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: "GET", path_info: ["healthz", "live"]} = conn, _opts) do
    respond(conn, 200, %{status: "live"})
  end

  def call(%Plug.Conn{method: "GET", path_info: ["healthz", "ready"]} = conn, _opts) do
    case Instance.readiness() do
      {:ok, checks} -> respond(conn, 200, %{status: "ready", checks: checks})
      {:error, checks} -> respond(conn, 503, %{status: "not_ready", checks: checks})
    end
  end

  def call(conn, _opts), do: conn

  defp respond(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(status, body |> Map.put(:version, version()) |> Jason.encode!())
    |> halt()
  end

  defp version, do: :hearth_web |> Application.spec(:vsn) |> to_string()
end
