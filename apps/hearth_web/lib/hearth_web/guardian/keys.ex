defmodule HearthWeb.Guardian.Keys do
  @behaviour Guardian.Token.Jwt.SecretFetcher

  alias JOSE.JWK

  @key {__MODULE__, :keys}
  @pem_end "-----END PUBLIC KEY-----"

  @spec load!() :: %{signing: JWK.t(), verifying: %{String.t() => JWK.t()}}
  def load! do
    config = Application.fetch_env!(:hearth_web, __MODULE__)
    signing = config |> Keyword.fetch!(:private_key) |> from_pem!(:private)

    previous =
      config[:previous_public_keys]
      |> split_pems()
      |> Enum.map(&from_pem!(&1, :public))

    verifying = Map.new([JWK.to_public(signing) | previous], &{kid(&1), &1})
    keys = %{signing: signing, verifying: verifying}

    :persistent_term.put(@key, keys)

    keys
  end

  @impl Guardian.Token.Jwt.SecretFetcher
  def fetch_signing_secret(_mod, _opts), do: {:ok, keys().signing}

  @impl Guardian.Token.Jwt.SecretFetcher
  def fetch_verifying_secret(_mod, %{"kid" => kid}, _opts) when is_binary(kid) do
    case Map.fetch(keys().verifying, kid) do
      {:ok, jwk} -> {:ok, jwk}
      :error -> {:error, :secret_not_found}
    end
  end

  def fetch_verifying_secret(_mod, _headers, _opts), do: {:error, :secret_not_found}

  defp keys do
    case :persistent_term.get(@key, nil) do
      nil -> load!()
      keys -> keys
    end
  end

  defp from_pem!(pem, kind) when is_binary(pem) do
    jwk = JWK.from_pem(pem)

    case jwk do
      %JWK{} -> check!(jwk, kind)
      _invalid -> raise ArgumentError, "a JWT key is not a valid PEM key"
    end
  end

  defp from_pem!(nil, _kind), do: raise(ArgumentError, "JWT_PRIVATE_KEY is not set")

  defp check!(jwk, kind) do
    {_kty, fields} = JWK.to_map(jwk)

    case fields do
      %{"kty" => "EC", "crv" => "P-256", "d" => _private} when kind == :private ->
        JWK.merge(jwk, %{"kid" => kid(jwk)})

      %{"kty" => "EC", "crv" => "P-256"} when kind == :public ->
        JWK.to_public(jwk)

      _other ->
        raise ArgumentError, "JWT keys must be EC P-256 #{kind} keys, for ES256"
    end
  end

  defp kid(jwk), do: jwk |> JWK.to_public() |> JWK.thumbprint()

  defp split_pems(nil), do: []

  defp split_pems(pems) do
    pems
    |> String.split(@pem_end, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&(&1 <> "\n" <> @pem_end))
  end
end
