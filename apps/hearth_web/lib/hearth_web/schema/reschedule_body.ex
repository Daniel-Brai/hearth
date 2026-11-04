defmodule HearthWeb.Schema.RescheduleBody do
  use JSV.Schema

  defschema %{
    title: "RescheduleBody",
    type: :object,
    required: [:send_at],
    additionalProperties: false,
    properties: %{
      send_at:
        string(format: :"date-time", description: "At least a minute and at most 30 days ahead")
    }
  }
end
