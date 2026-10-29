defmodule Hearth.Media.LinkFetch do
  import Bitwise

  @app :hearth
  @req_options Application.compile_env(@app, [__MODULE__, :req_options], [])

  @hops 3
  @timeout 5_000

  @type fetched :: %{url: String.t(), body: binary(), content_type: String.t()}

  # A page may be cut short since its tags sit in the head, while an image must arrive whole
  @spec page(String.t()) :: {:ok, fetched()} | {:error, atom()}
  def page(url) when is_binary(url),
    do:
      follow(
        url,
        %{max_bytes: 1_000_000, types: ["text/html", "application/xhtml+xml"], whole: false},
        @hops
      )

  @spec image(String.t()) :: {:ok, fetched()} | {:error, atom()}
  def image(url) when is_binary(url),
    do: follow(url, %{max_bytes: 5_000_000, types: ["image/"], whole: true}, @hops)

  # Every hop is checked again, so a public page can't redirect into the private network
  defp follow(_url, _limits, 0), do: {:error, :too_many_redirects}

  defp follow(url, limits, hops) do
    with {:ok, uri} <- web_uri(url),
         :ok <- public_host(uri.host),
         {:ok, response} <- fetch(url, limits.max_bytes) do
      answer(response, url, limits, hops)
    end
  end

  defp answer(%Req.Response{status: status} = response, url, limits, hops)
       when status in [301, 302, 303, 307, 308] do
    case Req.Response.get_header(response, "location") do
      [location | _rest] -> follow(next(url, location), limits, hops - 1)
      [] -> {:error, :unavailable}
    end
  end

  defp answer(%Req.Response{status: 200} = response, url, limits, _hops) do
    content_type = response |> Req.Response.get_header("content-type") |> List.first("")

    cond do
      limits.whole and byte_size(response.body) > limits.max_bytes -> {:error, :too_large}
      not Enum.any?(limits.types, &String.starts_with?(content_type, &1)) -> {:error, :wrong_type}
      true -> {:ok, %{url: url, body: response.body, content_type: content_type}}
    end
  end

  defp answer(%Req.Response{}, _url, _limits, _hops), do: {:error, :unavailable}

  defp next(url, location), do: url |> URI.merge(location) |> URI.to_string()

  defp web_uri(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host} = uri}
      when scheme in ~w[http https] and host not in [nil, ""] ->
        {:ok, uri}

      _invalid ->
        {:error, :invalid_url}
    end
  end

  defp public_host(host) do
    case addresses(host) do
      [] -> {:error, :unresolved}
      ips -> if Enum.any?(ips, &private?/1), do: {:error, :private_address}, else: :ok
    end
  end

  defp addresses(host) do
    name = String.to_charlist(host)

    case :inet.parse_address(name) do
      {:ok, ip} -> [ip]
      {:error, _reason} -> Enum.flat_map([:inet, :inet6], &resolve(name, &1))
    end
  end

  defp resolve(name, family) do
    case :inet.getaddrs(name, family) do
      {:ok, ips} -> ips
      {:error, _reason} -> []
    end
  end

  defp private?({a, _b, _c, _d}) when a in [0, 10, 127] or a >= 224, do: true
  defp private?({100, b, _c, _d}) when b in 64..127, do: true
  defp private?({169, 254, _c, _d}), do: true
  defp private?({172, b, _c, _d}) when b in 16..31, do: true
  defp private?({192, 168, _c, _d}), do: true
  defp private?({192, 0, 0, _d}), do: true
  defp private?({198, b, _c, _d}) when b in 18..19, do: true
  defp private?({_a, _b, _c, _d}), do: false
  defp private?({0, 0, 0, 0, 0, 0, 0, last}) when last in [0, 1], do: true

  defp private?({0, 0, 0, 0, 0, 0xFFFF, high, low}),
    do: private?({high >>> 8, high &&& 255, low >>> 8, low &&& 255})

  defp private?({first, _b, _c, _d, _e, _f, _g, _h}) when first in 0xFC00..0xFDFF, do: true
  defp private?({first, _b, _c, _d, _e, _f, _g, _h}) when first in 0xFE80..0xFEBF, do: true
  defp private?({first, _b, _c, _d, _e, _f, _g, _h}) when first >= 0xFF00, do: true
  defp private?({_a, _b, _c, _d, _e, _f, _g, _h}), do: false

  defp fetch(url, max_bytes), do: url |> build(max_bytes) |> Req.get()

  # The body stops at max_bytes, which for a page still holds the head with its tags
  defp build(url, max_bytes) do
    [
      url: url,
      redirect: false,
      retry: false,
      decode_body: false,
      receive_timeout: @timeout,
      connect_options: [timeout: @timeout],
      headers: [{"user-agent", "HearthBot/1.0 (link previews)"}, {"accept", "text/html, image/*"}],
      into: &collect(&1, &2, max_bytes)
    ]
    |> Keyword.merge(@req_options)
    |> Req.new()
  end

  defp collect({:data, data}, {request, response}, max_bytes) do
    response = %{response | body: (response.body || "") <> data}

    case byte_size(response.body) > max_bytes do
      true -> {:halt, {request, response}}
      false -> {:cont, {request, response}}
    end
  end
end
