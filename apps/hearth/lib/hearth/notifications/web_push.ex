defmodule Hearth.Notifications.WebPush do
  alias Hearth.Common
  alias JOSE.JWK
  alias JOSE.JWS
  alias JOSE.JWT
  alias Req.Response

  @req_options Application.compile_env(:hearth, [__MODULE__, :req_options], [])

  @type keys :: %{public: String.t(), private: String.t()}

  @spec enabled?() :: boolean()
  def enabled?, do: vapid_keys() != nil

  @spec vapid_keys() :: nil | keys()
  def vapid_keys do
    config = config()

    case {config[:public_key], config[:private_key]} do
      {public, private} when public in [nil, ""] or private in [nil, ""] -> nil
      {public, private} -> %{public: public, private: private}
    end
  end

  @spec generate_vapid_keys() :: keys()
  def generate_vapid_keys do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :prime256v1)

    %{
      public: Base.url_encode64(public_key, padding: false),
      private: Base.url_encode64(private_key, padding: false)
    }
  end

  @spec generate_jwt!(String.t(), keys()) :: String.t()
  def generate_jwt!(endpoint, %{public: _, private: _} = keys) when is_binary(endpoint) do
    public_key = url_decode64!(keys.public)
    private_key = url_decode64!(keys.private)
    %URI{scheme: scheme, host: host} = URI.parse(endpoint)

    jwt =
      JWT.from_map(%{
        aud: "#{scheme}://#{host}",
        sub: config()[:subject],
        exp: DateTime.to_unix(DateTime.utc_now()) + 12 * 3600
      })

    jwk =
      JWK.from_key({
        :ECPrivateKey,
        1,
        private_key,
        {:namedCurve, {1, 2, 840, 10_045, 3, 1, 7}},
        public_key,
        nil
      })

    {%{alg: :jose_jws_alg_ecdsa}, signed_token} =
      jwk
      |> JWT.sign(%{"alg" => "ES256"}, jwt)
      |> JWS.compact()

    signed_token
  end

  @spec send(map(), String.t(), keyword()) ::
          :ok | {:error, :expired | :payload_too_large | Response.t() | Exception.t()}
  def send(%{endpoint: endpoint} = subscription, message, opts)
      when is_binary(message) and is_list(opts) do
    opts = Keyword.validate!(opts, [:vapid_keys, ttl: 24 * 3600, urgency: "normal", topic: nil])
    vapid_keys = Keyword.fetch!(opts, :vapid_keys)

    headers =
      Enum.reject(
        [
          {"authorization",
           "vapid t=#{generate_jwt!(endpoint, vapid_keys)},k=#{vapid_keys.public}"},
          {"content-encoding", "aes128gcm"},
          {"content-type", "application/octet-stream"},
          {"ttl", Integer.to_string(opts[:ttl])},
          {"urgency", opts[:urgency]},
          {"topic", opts[:topic]}
        ],
        &match?({_name, nil}, &1)
      )

    request =
      Keyword.merge(
        [
          method: :post,
          url: endpoint,
          headers: headers,
          body: encrypt_aes128gcm!(message, subscription)
        ],
        @req_options
      )

    # Only the push service's host, since the endpoint itself identifies the device
    Common.span("web_push.send", %{host: URI.parse(endpoint).host}, fn ->
      request |> Req.request() |> handle_response()
    end)
  end

  @salt_length 16
  @curve :prime256v1

  @spec encrypt_aes128gcm!(String.t(), map()) :: binary()
  def encrypt_aes128gcm!(message, %{auth: auth, p256dh: p256dh})
      when is_binary(p256dh) and is_binary(auth) do
    client_auth_secret = url_decode64!(auth)
    client_public_key = url_decode64!(p256dh)

    salt = :crypto.strong_rand_bytes(@salt_length)
    {as_public_key, as_private_key} = :crypto.generate_key(:ecdh, @curve)
    shared_secret = :crypto.compute_key(:ecdh, client_public_key, as_private_key, @curve)

    ikm = derive_ikm(client_auth_secret, shared_secret, client_public_key, as_public_key)
    prk = hkdf_extract(salt, ikm)
    content_encryption_key = hkdf_expand(prk, "Content-Encoding: aes128gcm" <> <<0>>, 16)
    nonce = hkdf_expand(prk, "Content-Encoding: nonce" <> <<0>>, 12)

    # A 0x02 byte marks the last record
    {cipher_text, cipher_tag} =
      :crypto.crypto_one_time_aead(
        :aes_128_gcm,
        content_encryption_key,
        nonce,
        message <> <<0x02>>,
        "",
        true
      )

    build_encrypted_body(salt, as_public_key, cipher_text, cipher_tag)
  end

  defp handle_response({:ok, %Response{status: status}}) when status in 200..299, do: :ok

  defp handle_response({:ok, %Response{status: status}}) when status in [404, 410],
    do: {:error, :expired}

  defp handle_response({:ok, %Response{status: 413}}), do: {:error, :payload_too_large}
  defp handle_response({:ok, %Response{} = response}), do: {:error, response}
  defp handle_response({:error, _reason} = error), do: error

  # key_info = "WebPush: info" || 0x00 || ua_public || as_public
  defp derive_ikm(client_auth_secret, shared_secret, client_public_key, as_public_key) do
    key_info = "WebPush: info" <> <<0>> <> client_public_key <> as_public_key

    client_auth_secret
    |> hkdf_extract(shared_secret)
    |> hkdf_expand(key_info, 32)
  end

  defp hkdf_extract(salt, ikm), do: :crypto.mac(:hmac, :sha256, salt, ikm)

  defp hkdf_expand(prk, info, length) do
    :hmac
    |> :crypto.mac(:sha256, prk, info <> <<1>>)
    |> :binary.part(0, length)
  end

  # 86 byte header of salt 16 record size 4 key id length 1 and key id 65
  defp build_encrypted_body(salt, as_public_key, cipher_text, cipher_tag) do
    record_size = max(byte_size(cipher_text) + byte_size(cipher_tag) + 1, 4096)

    header =
      <<salt::binary-size(16), record_size::unsigned-big-integer-size(32),
        65::unsigned-integer-size(8), as_public_key::binary-size(65)>>

    header <> cipher_text <> cipher_tag
  end

  defp url_decode64!(value) do
    value
    |> String.trim_trailing("=")
    |> Base.url_decode64!(padding: false)
  end

  defp config, do: Application.get_env(:hearth, __MODULE__, [])
end
