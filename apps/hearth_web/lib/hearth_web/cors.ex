defmodule HearthWeb.Cors do
  @spec allowed_origin?(Plug.Conn.t(), String.t()) :: boolean()
  def allowed_origin?(_conn, origin) do
    public_url = Application.fetch_env!(:hearth, :public_url)

    String.trim_trailing(origin, "/") == String.trim_trailing(public_url, "/")
  end
end
