defmodule HearthWeb.Schema.TranscriptSpeaker do
  use JSV.Schema

  defschema %{
    title: "TranscriptSpeaker",
    type: :object,
    required: [:id, :index, :user_id, :label],
    properties: %{
      id: uuid(),
      index: non_neg_integer(),
      user_id: nullable(uuid(description: "Null once the account is gone")),
      label: nullable(string())
    }
  }
end
