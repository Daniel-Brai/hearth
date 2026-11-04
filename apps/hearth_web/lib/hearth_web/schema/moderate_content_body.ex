defmodule HearthWeb.Schema.ModerateContentBody do
  use JSV.Schema

  alias Hearth.Moderation.Item
  alias HearthWeb.Schema

  defschema %{
    title: "ModerateContentBody",
    type: :object,
    required: [:subject_type, :subject_id],
    additionalProperties: false,
    properties: %{
      subject_type: Schema.enum_of(Item, :subject_type),
      subject_id: uuid(),
      reason: nullable(string(maxLength: 500, description: "Required to remove"))
    }
  }
end
