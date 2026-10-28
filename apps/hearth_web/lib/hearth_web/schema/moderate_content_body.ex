defmodule HearthWeb.Schema.ModerateContentBody do
  use JSV.Schema

  defschema %{
    title: "ModerateContentBody",
    type: :object,
    required: [:subject_type, :subject_id],
    additionalProperties: false,
    properties: %{
      subject_type: enum(~w[post reply message]),
      subject_id: uuid(),
      reason: nullable(string(maxLength: 500, description: "Required to remove"))
    }
  }
end
