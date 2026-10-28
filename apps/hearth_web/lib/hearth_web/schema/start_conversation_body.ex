defmodule HearthWeb.Schema.StartConversationBody do
  use JSV.Schema

  defschema %{
    title: "StartConversationBody",
    type: :object,
    required: [:user_ids],
    additionalProperties: false,
    properties: %{
      user_ids:
        array_of(uuid(),
          minItems: 1,
          maxItems: 20,
          uniqueItems: true,
          description: "One person for a direct conversation, more for a group"
        ),
      name: nullable(string(minLength: 1, maxLength: 60))
    }
  }
end
