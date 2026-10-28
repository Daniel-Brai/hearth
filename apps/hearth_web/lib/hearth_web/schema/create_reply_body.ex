defmodule HearthWeb.Schema.CreateReplyBody do
  use JSV.Schema

  defschema %{
    title: "CreateReplyBody",
    type: :object,
    required: [:body],
    additionalProperties: false,
    properties: %{
      body: string(maxLength: 10_000, description: "Can be empty with files attached"),
      attachment_ids:
        array_of(uuid(),
          description: "On an edit, left out keeps the current files"
        ),
      parent_reply_id: nullable(uuid(description: "Null for the top level"))
    }
  }
end
