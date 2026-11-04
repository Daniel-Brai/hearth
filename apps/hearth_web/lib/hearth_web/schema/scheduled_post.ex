defmodule HearthWeb.Schema.ScheduledPost do
  use JSV.Schema

  alias HearthWeb.Schema.Media

  defschema %{
    title: "ScheduledPost",
    type: :object,
    description: "A post waiting for its time, seen only by its author",
    required: ~w[id community_id kind_id title body attachments send_at failure]a,
    properties: %{
      id: uuid(),
      community_id: uuid(),
      kind_id: nullable(uuid()),
      title: string(),
      body: string(),
      attachments: array_of(Media),
      send_at: string(format: :"date-time"),
      failure:
        nullable(string(description: "Why it couldn't go up, such as forbidden or unknown_kind"))
    }
  }
end
