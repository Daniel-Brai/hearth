defmodule Hearth.Media.Command.BuildLinkPreview do
  alias Hearth.Media.LinkFetch
  alias Hearth.Media.LinkPage
  alias Hearth.Media.LinkPreview

  @spec execute(String.t()) :: {:ok, LinkPreview.t()} | {:error, atom()}
  def execute(url) when is_binary(url) do
    with {:ok, page} <- LinkFetch.page(url),
         {:ok, found} <- LinkPage.parse(page.body, page.url) do
      {:ok, struct!(LinkPreview, Map.put(found, :url, url))}
    end
  end
end
