defmodule HearthWeb.Schema.ReportReceipt do
  use JSV.Schema

  defschema %{
    title: "ReportReceipt",
    type: :object,
    required: [:queued],
    properties: %{
      queued: boolean()
    }
  }
end
