defmodule Hearth.Media.LinkPreview do
  @enforce_keys ~w[url site title]a
  defstruct ~w[url site title description image_url]a

  # The image is the site's own, loaded straight from it
  @type t :: %__MODULE__{
          url: String.t(),
          site: String.t(),
          title: String.t(),
          description: nil | String.t(),
          image_url: nil | String.t()
        }
end
