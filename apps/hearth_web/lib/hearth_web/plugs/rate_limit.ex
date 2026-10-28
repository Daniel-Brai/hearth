defmodule HearthWeb.Plugs.RateLimit do
  @behaviour Plug

  import Plug.Conn

  alias Hearth.RateLimit
  alias HearthWeb.ErrorResponse
  alias HearthWeb.FloodGuard
  alias Phoenix.Controller

  @flood_limit if(Mix.env() == :test, do: 10_000, else: 300)

  @impl Plug
  def init(opts) do
    Keyword.validate!(opts, [:action, limit: @flood_limit, scale: :timer.minutes(1), by: :ip])
  end

  @impl Plug
  def call(conn, opts) do
    limit = Keyword.fetch!(opts, :limit)
    scale = Keyword.fetch!(opts, :scale)

    result =
      case Keyword.fetch(opts, :action) do
        :error -> conn |> client(:ip) |> FloodGuard.hit(scale, limit)
        {:ok, action} -> conn |> key(action, opts[:by]) |> RateLimit.hit(scale, limit)
      end

    case result do
      {:allow, _count} ->
        conn

      {:deny, retry_after} ->
        seconds = div(retry_after, 1_000) + 1

        conn
        |> put_resp_header("retry-after", to_string(seconds))
        |> ErrorResponse.halt(:too_many_requests, :rate_limited)
    end
  end

  defmacro rate_limit(action, opts) when is_atom(action) do
    quote do
      plug HearthWeb.Plugs.RateLimit,
           Keyword.put(unquote(opts), :action, unquote(action))
           when var!(action) == unquote(action)
    end
  end

  defp key(conn, action, by) do
    controller = conn |> Controller.controller_module() |> inspect()

    "#{controller}.#{action}:#{client(conn, by)}"
  end

  defp client(%{assigns: %{auth: %{id: id}}}, :user), do: "user:" <> id

  defp client(conn, {:body, field}) do
    value =
      case conn.body_params do
        %{} = params -> params[Atom.to_string(field)]
        _unfetched -> nil
      end

    case value do
      value when is_binary(value) -> "#{field}:" <> (value |> String.trim() |> String.downcase())
      _missing -> client(conn, :ip)
    end
  end

  defp client(conn, _by), do: "ip:" <> (conn.remote_ip |> :inet.ntoa() |> to_string())
end
