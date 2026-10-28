defmodule Hearth.Instance.Releases do
  alias Hearth.Instance.GitHubError
  alias Hearth.Instance.Release

  @app :hearth
  @req_options Application.compile_env(@app, [__MODULE__, :req_options], [])

  @spec latest() :: {:ok, nil | Release.t()} | {:error, GitHubError.t() | Exception.t()}
  def latest do
    request = build(url: "/releases/latest")

    with {:ok, response} <- Req.get(request) do
      parse_result(response)
    end
  end

  def build(opts) do
    version = @app |> Application.spec(:vsn) |> to_string()

    headers = [
      {"accept", "application/vnd.github+json"},
      {"x-github-api-version", "2022-11-28"},
      {"user-agent", "Hearth/#{version}"}
    ]

    opts
    |> Keyword.merge(@req_options)
    |> Keyword.put(:base_url, config(:base_url))
    |> Keyword.put(:headers, headers)
    |> Req.new()
  end

  def parse_result(response) do
    case response do
      %Req.Response{status: 200, body: body} -> {:ok, Release.from!(body)}
      %Req.Response{status: 404} -> {:ok, nil}
      %Req.Response{status: status, body: body} -> {:error, error(status, body)}
    end
  end

  @spec enabled?() :: boolean()
  def enabled?, do: config(:enabled) != false

  # A proxy or outage may send no error body so the status always comes from the response
  defp error(status, %{} = body), do: body |> Map.put("status", status) |> GitHubError.from!()
  defp error(status, _body), do: GitHubError.from!(%{"status" => status})

  defp config(key), do: @app |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(key)
end
