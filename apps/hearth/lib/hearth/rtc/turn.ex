defmodule Hearth.RTC.Turn do
  # coturn checks the credential again on every allocation refresh so a login has to outlast its session
  alias Hearth.Common.T

  @type ice_server :: %{urls: [String.t()], username: String.t(), credential: String.t()}

  @spec ice_servers(T.id(), keyword()) :: [ice_server()]
  def ice_servers(user_id, config) do
    case {config[:turn_url], config[:turn_secret]} do
      {url, secret} when is_binary(url) and url != "" and is_binary(secret) and secret != "" ->
        {username, credential} = credentials(user_id, secret, config[:turn_ttl], now())
        [%{urls: urls(url), username: username, credential: credential}]

      _unset ->
        []
    end
  end

  @spec credentials(String.t(), String.t(), pos_integer(), non_neg_integer()) ::
          {String.t(), String.t()}
  def credentials(user_id, secret, ttl, now) do
    username = "#{now + ttl}:#{user_id}"
    credential = :hmac |> :crypto.mac(:sha, secret, username) |> Base.encode64()

    {username, credential}
  end

  # A host like turn.example.com becomes the UDP and TCP URLs on 3478
  # A full turn or turns URL or several separated by commas is used as it is
  defp urls(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn
      "turn:" <> _rest = url -> [url]
      "turns:" <> _rest = url -> [url]
      host -> ["turn:#{host}:3478?transport=udp", "turn:#{host}:3478?transport=tcp"]
    end)
  end

  defp now, do: System.os_time(:second)
end
