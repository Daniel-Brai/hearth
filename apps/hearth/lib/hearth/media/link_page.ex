defmodule Hearth.Media.LinkPage do
  @title_length 200
  @description_length 300

  @type found :: %{
          site: String.t(),
          title: String.t(),
          description: nil | String.t(),
          image_url: nil | String.t()
        }

  # Only pages that describe themselves for previews get a card. A bare <title> isn't enough
  @spec parse(binary(), String.t()) :: {:ok, found()} | {:error, :no_preview | :unreadable}
  def parse(html, url) when is_binary(html) and is_binary(url) do
    case Floki.parse_document(html) do
      {:ok, document} -> document |> meta() |> found(url) |> shown()
      {:error, _reason} -> {:error, :unreadable}
    end
  end

  defp found(tags, url) do
    description = tags["og:description"] || tags["twitter:description"] || tags["description"]

    %{
      site: clean(tags["og:site_name"], @title_length) || host(url),
      title: clean(tags["og:title"] || tags["twitter:title"], @title_length),
      description: clean(description, @description_length),
      image_url: image(tags, url)
    }
  end

  defp shown(%{title: nil}), do: {:error, :no_preview}
  defp shown(%{description: nil, image_url: nil}), do: {:error, :no_preview}
  defp shown(found), do: {:ok, found}

  defp meta(document) do
    document
    |> Floki.find("meta")
    |> Enum.reduce(%{}, fn {"meta", attributes, _children}, tags ->
      attributes = Map.new(attributes)
      key = attributes["property"] || attributes["name"]

      case {key, attributes["content"]} do
        {key, content} when is_binary(key) and is_binary(content) ->
          Map.put_new(tags, String.downcase(key), content)

        _missing ->
          tags
      end
    end)
  end

  defp image(tags, url) do
    case tags["og:image:secure_url"] || tags["og:image"] || tags["twitter:image"] do
      nil -> nil
      image -> url |> URI.merge(String.trim(image)) |> web_image()
    end
  end

  defp web_image(%URI{scheme: scheme} = uri) when scheme in ~w[http https], do: URI.to_string(uri)
  defp web_image(%URI{}), do: nil

  defp host(url), do: url |> URI.parse() |> Map.fetch!(:host) |> String.replace_prefix("www.", "")

  defp clean(nil, _max_length), do: nil

  defp clean(text, max_length) do
    text = text |> String.replace(~r/\s+/u, " ") |> String.trim()

    cond do
      text == "" -> nil
      String.length(text) > max_length -> String.slice(text, 0, max_length - 1) <> "…"
      true -> text
    end
  end
end
