defmodule HearthWeb.Schema.ScheduledMessage do
  use JSV.Schema

  alias HearthWeb.Schema.Media

  defschema %{
    title: "ScheduledMessage",
    type: :object,
    description: "A message waiting for its time, seen only by its author",
    required: ~w[id room_id conversation_id body attachments send_at failure]a,
    properties: %{
      id: uuid(),
      room_id: nullable(uuid()),
      conversation_id: nullable(uuid()),
      body: string(),
      attachments: array_of(Media),
      send_at: string(format: :"date-time"),
      failure:
        nullable(string(description: "Why it couldn't send, such as forbidden or archived"))
    }
  }
end
