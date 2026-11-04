defmodule HearthWeb.Schema.QueueReport do
  use JSV.Schema

  alias Hearth.Moderation.Report
  alias HearthWeb.Schema

  defschema %{
    title: "QueueReport",
    type: :object,
    description: "Who sent it isn't shown",
    required: [:reason, :note, :inserted_at],
    properties: %{
      reason: Schema.enum_of(Report, :reason),
      note: nullable(string()),
      inserted_at: string(format: :"date-time")
    }
  }
end
