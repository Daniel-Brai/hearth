defmodule HearthWeb.UploadJSON do
  alias HearthWeb.MediaJSON

  def create(%{media: media, upload: upload}),
    do: %{media: MediaJSON.serialize(media), upload: upload}

  def parts(%{parts: parts}) do
    %{parts: Enum.map(parts, &Map.take(&1, ~w[number etag size]a))}
  end

  def part_urls(%{urls: urls}),
    do: %{urls: Map.new(urls, fn {number, url} -> {to_string(number), url} end)}

  def complete(%{media: media}), do: MediaJSON.serialize(media)
end
