defmodule HearthWeb.LinkPreviewJSON do
  def show(%{preview: preview}),
    do: Map.take(preview, ~w[url site title description image_url]a)
end
