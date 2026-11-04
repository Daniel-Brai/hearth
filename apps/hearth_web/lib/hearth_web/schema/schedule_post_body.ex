defmodule HearthWeb.Schema.SchedulePostBody do
  use JSV.Schema

  defschema %{
    title: "SchedulePostBody",
    type: :object,
    required: [:kind_id, :title, :send_at],
    additionalProperties: false,
    properties: %{
      kind_id: uuid(),
      title: string(minLength: 1, maxLength: 150),
      body: string(maxLength: 40_000),
      attachment_ids: array_of(uuid(), maxItems: 10),
      send_at:
        string(format: :"date-time", description: "At least a minute and at most 30 days ahead")
    }
  }
end
