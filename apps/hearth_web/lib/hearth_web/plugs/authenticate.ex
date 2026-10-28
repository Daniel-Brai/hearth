defmodule HearthWeb.Plugs.Authenticate do
  @behaviour Guardian.Plug.ErrorHandler

  use Guardian.Plug.Pipeline,
    otp_app: :hearth_web,
    module: HearthWeb.Guardian,
    error_handler: __MODULE__

  alias HearthWeb.ErrorResponse
  alias Plug.Conn

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer", claims: %{"typ" => "access"}
  plug Guardian.Plug.LoadResource, allow_blank: true
  plug :assign_auth

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {_type, _reason}, _opts) do
    ErrorResponse.halt(
      conn,
      :unauthorized,
      :invalid_token,
      "The access token is invalid or expired."
    )
  end

  @spec assign_auth(Conn.t(), keyword()) :: Conn.t()
  def assign_auth(conn, _opts) do
    user = Guardian.Plug.current_resource(conn)

    if user, do: Logger.metadata(user_id: user.id)

    Conn.assign(conn, :auth, user)
  end
end
