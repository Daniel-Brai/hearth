defmodule HearthWeb.Schema.ReportBody do
  use JSV.Schema

  alias Hearth.Moderation.Item
  alias Hearth.Moderation.Report
  alias HearthWeb.Schema

  defschema %{
    title: "ReportBody",
    type: :object,
    required: [:subject_type, :subject_id, :reason],
    additionalProperties: false,
    properties: %{
      subject_type: Schema.enum_of(Item, :subject_type),
      subject_id: uuid(),
      reason: Schema.enum_of(Report, :reason),
      note: nullable(string(maxLength: 1000))
    }
  }
end
