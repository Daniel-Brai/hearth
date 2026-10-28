defmodule HearthWeb.Schema.ReportBody do
  use JSV.Schema

  defschema %{
    title: "ReportBody",
    type: :object,
    required: [:subject_type, :subject_id, :reason],
    additionalProperties: false,
    properties: %{
      subject_type: enum(~w[post reply message]),
      subject_id: uuid(),
      reason: enum(~w[spam harassment hate sexual violence off_topic other]),
      note: nullable(string(maxLength: 1000))
    }
  }
end
