defmodule HearthWeb.Schema.RequestUploadBody do
  use JSV.Schema

  defschema %{
    title: "RequestUploadBody",
    type: :object,
    required: ~w[name content_type byte_size sha256]a,
    additionalProperties: false,
    properties: %{
      name: string(minLength: 1, maxLength: 255),
      content_type: string(minLength: 1, maxLength: 255),
      byte_size: pos_integer(),
      sha256: string(pattern: "^[0-9a-fA-F]{64}$"),
      purpose: enum(~w[attachment avatar logo]),
      duration_ms: pos_integer(description: "As the browser read it, checked again later")
    }
  }
end
