defmodule HearthWeb.RequestLogger do
  alias Phoenix.Logger, as: PhoenixLogger
  alias Phoenix.Router
  alias Plug.Conn

  require Logger

  @event ~w[phoenix endpoint stop]a
  @hidden_headers ~w[authorization cookie set-cookie]
  # A sign in code only ever arrives in a request, and code in an answer is the error's name
  # At runtime Phoenix swaps the setting for a compiled matcher, so the list is read here
  @response_filter Application.compile_env(:phoenix, :filter_parameters, []) -- ["code"]

  @spec install() :: :ok | {:error, :already_exists}
  def install do
    :telemetry.attach({__MODULE__, :stop}, @event, &__MODULE__.handle_event/4, nil)
  end

  @doc false
  def handle_event(@event, %{duration: duration}, %{conn: conn}, _config) do
    duration_ms = System.convert_time_unit(duration, :native, :microsecond) / 1_000
    level = level(conn)

    metadata = [
      method: conn.method,
      path: conn.request_path,
      route: route(conn),
      status: conn.status,
      duration_ms: Float.round(duration_ms, 1),
      remote_ip: conn.remote_ip |> :inet.ntoa() |> to_string()
    ]

    Logger.log(
      level,
      fn -> "#{conn.method} #{conn.request_path} #{conn.status} in #{round(duration_ms)}ms" end,
      metadata
    )

    if bodies?(), do: Logger.debug(fn -> insight(conn) end)
  end

  defp level(%Conn{status: status}) when status >= 500, do: :error
  defp level(%Conn{path_info: ["healthz" | _check]}), do: :debug
  defp level(_conn), do: :info

  defp route(conn) do
    with router when router != nil <- conn.private[:phoenix_router],
         %{route: route} <-
           Router.route_info(router, conn.method, conn.request_path, conn.host) do
      route
    else
      _no_route -> nil
    end
  end

  defp insight(conn) do
    [
      "Request\n",
      headers(conn.req_headers),
      "  ",
      params(conn.params),
      "\nResponse\n",
      headers(conn.resp_headers),
      "  ",
      response_body(conn)
    ]
  end

  defp headers(headers) do
    for {name, value} <- headers do
      value = if name in @hidden_headers, do: "[FILTERED]", else: value
      ["  ", name, ": ", value, ?\n]
    end
  end

  defp params(%Conn.Unfetched{}), do: "[UNFETCHED]"
  defp params(params), do: params |> PhoenixLogger.filter_values() |> Jason.encode_to_iodata!()

  defp response_body(conn) do
    case Conn.get_resp_header(conn, "content-type") do
      ["application/json" <> _rest] -> filter_json(conn.resp_body)
      _other -> "[NOT JSON]"
    end
  end

  defp filter_json(nil), do: ""

  defp filter_json(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        decoded |> PhoenixLogger.filter_values(@response_filter) |> Jason.encode_to_iodata!()

      {:error, _reason} ->
        "[INVALID JSON]"
    end
  end

  defp bodies?, do: Application.get_env(:hearth_web, __MODULE__, [])[:bodies] == true
end
