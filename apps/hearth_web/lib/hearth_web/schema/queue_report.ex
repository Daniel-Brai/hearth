defmodule HearthWeb.Schema.QueueReport do
  use JSV.Schema

  defschema %{
    title: "QueueReport",
    type: :object,
    description: "Who sent it isn't shown",
    required: [:reason, :note, :inserted_at],
    properties: %{
      reason: enum(~w[spam harassment hate sexual violence off_topic other]),
      note: nullable(string()),
      inserted_at: string(format: :"date-time")
    }
  }
end
