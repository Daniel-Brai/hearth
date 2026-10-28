defmodule HearthWeb.Schema.PromoteBody do
  use JSV.Schema

  defschema %{
    title: "PromoteBody",
    type: :object,
    required: [:message_ids, :kind_id, :title],
    additionalProperties: false,
    properties: %{
      message_ids:
        array_of(uuid(),
          minItems: 1,
          maxItems: 50,
          uniqueItems: true,
          description: "In any order since they are put in the order they were sent"
        ),
      kind_id: uuid(),
      title: string(minLength: 1, maxLength: 150)
    }
  }
end
