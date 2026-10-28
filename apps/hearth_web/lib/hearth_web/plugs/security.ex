defmodule HearthWeb.Plugs.Security do
  @behaviour Plug

  alias HearthWeb.ErrorResponse

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    bearer? =
      opts
      |> Keyword.get(:security)
      |> List.wrap()
      |> Enum.any?(&Map.has_key?(&1, "bearer"))

    case bearer? and is_nil(conn.assigns[:auth]) do
      true -> ErrorResponse.halt(conn, :unauthorized, :missing_token, "Sign in first.")
      false -> conn
    end
  end
end
