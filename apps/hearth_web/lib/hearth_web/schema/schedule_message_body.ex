defmodule HearthWeb.Schema.ScheduleMessageBody do
  use JSV.Schema

  defschema %{
    title: "ScheduleMessageBody",
    type: :object,
    required: [:send_at],
    additionalProperties: false,
    properties: %{
      body: string(maxLength: 4000),
      attachment_ids: array_of(uuid(), maxItems: 10),
      send_at:
        string(format: :"date-time", description: "At least a minute and at most 30 days ahead")
    }
  }
end
