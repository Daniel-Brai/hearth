defmodule HearthWeb.Schema.MultipartUpload do
  use JSV.Schema

  defschema %{
    title: "MultipartUpload",
    type: :object,
    description: "Sign each part with POST /api/uploads/{id}/part-urls",
    required: [:upload_id, :part_size, :parts],
    properties: %{
      upload_id: string(),
      part_size: pos_integer(description: "In bytes, except the last part"),
      parts: pos_integer()
    }
  }
end
