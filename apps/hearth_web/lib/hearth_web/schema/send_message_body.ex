defmodule HearthWeb.Schema.SendMessageBody do
  use JSV.Schema

  defschema %{
    title: "SendMessageBody",
    type: :object,
    required: [:body],
    additionalProperties: false,
    properties: %{
      body: string(maxLength: 4_000, description: "Can be empty with files attached"),
      attachment_ids:
        array_of(uuid(),
          description: "On an edit, left out keeps the current files"
        ),
      reply_to_id: nullable(uuid())
    }
  }
end
