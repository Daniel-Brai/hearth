defmodule HearthWeb.Schema.UpdatePostBody do
  use JSV.Schema

  defschema %{
    title: "UpdatePostBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      kind_id: uuid(),
      title: string(minLength: 1, maxLength: 150),
      body: string(maxLength: 40_000),
      attachment_ids:
        array_of(uuid(),
          description: "On an edit, left out keeps the current files"
        )
    }
  }
end
