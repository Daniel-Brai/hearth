defmodule HearthWeb.Plugs.RequireCustomHeader do
  @moduledoc "A page on another site can't send Hearth-Version without a CORS preflight so a forged cookie request is refused"

  @behaviour Plug

  import Plug.Conn

  alias HearthWeb.ErrorResponse

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_req_header(conn, "hearth-version") do
      [_version] ->
        conn

      _missing ->
        ErrorResponse.halt(conn, :forbidden, :missing_header, "Send the Hearth-Version header.")
    end
  end
end
