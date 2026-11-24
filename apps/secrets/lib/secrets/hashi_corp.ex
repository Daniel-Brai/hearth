defmodule Secrets.HashiCorp do
  alias Secrets.HashiCorp.Error
  alias Secrets.HashiCorp.Secret
  alias Secrets.HashiCorp.Token

  @app :secrets
  @req_options Application.compile_env(@app, [__MODULE__, :req_options], [])

  @spec login!() :: no_return() | Token.t()
  def login! do
    case config(:auth) do
      "token" ->
        Token.from!(%{"auth" => %{"client_token" => config!(:token), "lease_duration" => 0}})

      method ->
        mount = config(:auth_mount) || method
        request = build(url: "/auth/#{mount}/login", json: credentials!(method))

        request |> Req.post!() |> parse_result(&Token.from!/1, nil)
    end
  end

  @spec read!(Token.t(), String.t()) :: no_return() | Secret.t()
  def read!(%Token{} = token, path) when is_binary(path) do
    [mount, rest] = String.split(path, "/", parts: 2)

    request =
      build(url: "/#{mount}/data/#{rest}", headers: [{"x-vault-token", token.client_token}])

    request |> Req.get!() |> parse_result(&Secret.from!/1, path)
  end

  defp build(opts) do
    headers =
      case config(:namespace) do
        nil -> []
        namespace -> [{"x-vault-namespace", namespace}]
      end

    opts
    |> Keyword.merge(@req_options)
    |> Keyword.put(:base_url, config!(:address) <> "/v1")
    |> Keyword.update(:headers, headers, &(headers ++ &1))
    |> Req.new()
  end

  defp parse_result(%Req.Response{status: 200, body: %{} = body}, from, _path), do: from.(body)

  defp parse_result(%Req.Response{status: status, body: body}, _from, path),
    do: raise(error(status, body, path))

  defp credentials!("kubernetes"), do: %{role: config!(:role), jwt: read_file!(:jwt_file)}

  defp credentials!("approle"),
    do: %{role_id: read_file!(:role_id_file), secret_id: read_file!(:secret_id_file)}

  defp credentials!(other), do: raise(ArgumentError, "Unknown VAULT_AUTH #{inspect(other)}")

  # Vault error messages name paths and policies but never secret values
  defp error(status, %{} = body, path),
    do: body |> Map.merge(%{"status" => status, "path" => path}) |> Error.from!()

  defp error(status, _body, path), do: Error.from!(%{"status" => status, "path" => path})

  # The path comes from the server's own configuration
  # sobelow_skip ["Traversal.FileModule"]
  defp read_file!(key), do: key |> config!() |> File.read!() |> String.trim()

  defp config(key), do: @app |> Confex.fetch_env!(__MODULE__) |> Keyword.get(key)

  defp config!(key) do
    case config(key) do
      value when is_binary(value) and value != "" -> value
      _missing -> raise ArgumentError, "#{key} must be set to read secrets from Vault"
    end
  end
end
