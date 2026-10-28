defmodule HearthWeb.Plugs.ApiDocs do
  @behaviour Plug

  import Phoenix.Controller
  import Plug.Conn

  alias HearthWeb.ErrorHTML
  alias HearthWeb.ErrorJSON

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case Application.fetch_env!(:hearth_web, :api_docs) do
      true -> conn
      false -> not_found(conn)
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(html: ErrorHTML, json: ErrorJSON)
    |> render(:"404")
    |> halt()
  end
end
