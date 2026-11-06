defmodule HearthWeb.Schema.StartPollBody do
  use JSV.Schema

  defschema %{
    title: "StartPollBody",
    type: :object,
    required: [:question, :options],
    additionalProperties: false,
    properties: %{
      question: string(minLength: 1, maxLength: 300),
      options: array_of(string(minLength: 1, maxLength: 100), minItems: 2, maxItems: 10),
      multiple: boolean(default: false),
      closes_at:
        nullable(
          string(
            format: :"date-time",
            description: "Closes by itself then, from a minute to a week ahead. Null stays open"
          )
        )
    }
  }
end
