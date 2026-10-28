defmodule HearthWeb.Paging do
  import Oaskit.Controller, only: [query_param: 2]

  @spec opts(Plug.Conn.t()) :: keyword()
  def opts(conn) do
    for key <- ~w[limit after before]a,
        value = query_param(conn, key),
        value != nil,
        do: {key, value}
  end
end
