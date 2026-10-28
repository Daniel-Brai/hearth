defmodule HearthWeb.Plugs.ApiVersion do
  @behaviour Plug

  import Plug.Conn

  alias HearthWeb.ErrorResponse

  @header "hearth-version"
  @versions ["2026-10-24"]

  @spec versions() :: [String.t(), ...]
  def versions, do: @versions

  @spec latest() :: String.t()
  def latest, do: List.last(@versions)

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_req_header(conn, @header) do
      [] -> answer_as(conn, hd(@versions))
      [version] when version in @versions -> answer_as(conn, version)
      _other -> ErrorResponse.halt(conn, :bad_request, :unsupported_version, unsupported())
    end
  end

  defp answer_as(conn, version) do
    Logger.metadata(api_version: version)

    conn
    |> assign(:api_version, version)
    |> put_resp_header(@header, version)
  end

  defp unsupported do
    "Hearth-Version must be one of: " <> Enum.join(@versions, ", ")
  end
end
