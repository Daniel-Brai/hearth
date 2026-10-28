defmodule Hearth.Vault do
  use Boundary, deps: [], exports: [Binary]

  @version 1
  @aad "hearth.vault.v1"
  @key {__MODULE__, :keys}

  @spec load!() :: :ok
  def load! do
    config = Confex.fetch_env!(:hearth, __MODULE__)
    current = config |> Keyword.fetch!(:key) |> decode!()

    previous =
      config
      |> Keyword.get(:previous_keys, "")
      |> to_string()
      |> String.split(",", trim: true)
      |> Enum.map(&decode!/1)

    keys = Map.new([current | previous], &{id(&1), &1})
    hash_key = config |> Keyword.fetch!(:hash_key) |> decode!()

    :persistent_term.put(@key, %{current: {id(current), current}, all: keys, hash: hash_key})

    :ok
  end

  @spec encrypt(binary()) :: binary()
  def encrypt(plaintext) when is_binary(plaintext) do
    {id, key} = keys().current
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)

    <<@version, id::binary-4, iv::binary-12, tag::binary-16, ciphertext::binary>>
  end

  @spec decrypt(binary()) :: {:ok, binary()} | :error
  def decrypt(<<@version, id::binary-4, iv::binary-12, tag::binary-16, ciphertext::binary>>) do
    with {:ok, key} <- Map.fetch(keys().all, id),
         plaintext when is_binary(plaintext) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
      {:ok, plaintext}
    else
      _unopened -> :error
    end
  end

  def decrypt(_value), do: :error

  # ENCRYPTION_HASH_KEY must never change, or every digest stops matching
  @spec hash(binary()) :: binary()
  def hash(value) when is_binary(value), do: :crypto.mac(:hmac, :sha256, keys().hash, value)

  defp keys do
    case :persistent_term.get(@key, nil) do
      nil ->
        :ok = load!()
        :persistent_term.get(@key)

      keys ->
        keys
    end
  end

  defp id(key), do: :sha256 |> :crypto.hash(key) |> binary_part(0, 4)

  defp decode!(encoded) do
    case encoded |> String.trim() |> Base.decode64() do
      {:ok, <<_key::binary-32>> = key} -> key
      _invalid -> raise ArgumentError, "an encryption key must be 32 bytes in base64"
    end
  end
end
