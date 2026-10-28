defmodule HearthWeb.Schema.EditBody do
  use JSV.Schema

  defschema %{
    title: "EditBody",
    type: :object,
    required: [:body],
    additionalProperties: false,
    properties: %{
      body: string(maxLength: 10_000, description: "Can be empty with files attached"),
      attachment_ids:
        array_of(uuid(),
          description: "On an edit, left out keeps the current files"
        )
    }
  }
end
