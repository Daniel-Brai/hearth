defmodule HearthWeb.ErrorResponse do
  import Plug.Conn

  alias Plug.Conn
  alias Plug.Conn.Status

  @spec halt(Conn.t(), atom() | pos_integer(), atom(), nil | String.t()) :: Conn.t()
  def halt(conn, status, code, message \\ nil) do
    status = Status.code(status)
    body = %{message: message || Status.reason_phrase(status), code: code}

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode_to_iodata!(body))
    |> Conn.halt()
  end
end
