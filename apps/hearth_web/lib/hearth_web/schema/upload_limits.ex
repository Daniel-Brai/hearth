defmodule HearthWeb.Schema.UploadLimits do
  use JSV.Schema

  defschema %{
    title: "UploadLimits",
    type: :object,
    required: ~w[
      content_types
      max_image_bytes
      max_video_bytes
      max_video_seconds
      max_file_bytes
      max_attachments
    ]a,
    properties: %{
      content_types: array_of(string()),
      max_image_bytes: pos_integer(),
      max_video_bytes: pos_integer(),
      max_video_seconds: pos_integer(),
      max_file_bytes: pos_integer(),
      max_attachments: pos_integer(description: "Per post, reply or message")
    }
  }
end
