defmodule HearthWeb.Schema.AnswerBody do
  use JSV.Schema

  defschema %{
    title: "AnswerBody",
    type: :object,
    required: [:reply_id],
    additionalProperties: false,
    properties: %{reply_id: nullable(uuid(description: "Null clears the answer"))}
  }
end
