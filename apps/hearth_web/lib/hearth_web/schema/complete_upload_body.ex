defmodule HearthWeb.Schema.CompleteUploadBody do
  use JSV.Schema

  defschema %{
    title: "CompleteUploadBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      parts:
        array_of(
          %{
            type: :object,
            required: [:number, :etag],
            additionalProperties: false,
            properties: %{
              number: integer(minimum: 1, maximum: 10_000),
              etag: string(minLength: 1, maxLength: 128)
            }
          },
          maxItems: 10_000,
          description: "Number and ETag of each part"
        )
    }
  }
end
