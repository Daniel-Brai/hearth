defmodule Hearth.Common.MailDomain do
  # :unknown means DNS timed out so a slow resolver never turns someone away
  # The .invalid domain never exists so tests stay off the network

  @type status :: :reachable | :unreachable | :unknown

  @spec address_status(String.t()) :: status() | :invalid
  def address_status(email) when is_binary(email) do
    case EmailChecker.valid?(email) do
      true -> status(email)
      false -> :invalid
    end
  end

  @spec status(String.t()) :: status()
  def status(email) when is_binary(email) do
    domain = email |> String.split("@") |> List.last() |> String.downcase()

    cond do
      String.ends_with?(domain, ".invalid") -> :unreachable
      not lookups?() -> :unknown
      true -> look_up(String.to_charlist(domain))
    end
  end

  defp look_up(domain) do
    case resolve(domain, :mx) do
      {:ok, [_record | _records]} -> :reachable
      {:ok, []} -> address_record(domain)
      {:error, :nxdomain} -> :unreachable
      {:error, _reason} -> :unknown
    end
  end

  # With no mail servers listed, mail goes to the domain's own address
  defp address_record(domain) do
    case resolve(domain, :a) do
      {:ok, [_record | _records]} -> :reachable
      {:ok, []} -> :unreachable
      {:error, _reason} -> :unknown
    end
  end

  defp resolve(domain, type) do
    case :inet_res.resolve(domain, :in, type, [], timeout()) do
      {:ok, message} -> {:ok, :inet_dns.msg(message, :anlist)}
      {:error, {reason, _message}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  defp lookups?, do: Application.get_env(:hearth, __MODULE__, [])[:lookups] != false

  defp timeout, do: Application.get_env(:hearth, __MODULE__, [])[:timeout] || 3_000
end
