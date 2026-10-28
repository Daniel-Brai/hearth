defmodule HearthWeb.Schema.Upload do
  use JSV.Schema

  alias HearthWeb.Schema.Media
  alias HearthWeb.Schema.MultipartUpload
  alias HearthWeb.Schema.SingleUpload

  defschema %{
    title: "Upload",
    type: :object,
    required: [:media, :upload],
    properties: %{
      media: Media,
      upload: one_of([SingleUpload, MultipartUpload, %{type: :null}])
    }
  }
end
