defmodule HearthWeb.Schema.Poll do
  use JSV.Schema

  alias HearthWeb.Schema.PollOption

  defschema %{
    title: "Poll",
    type: :object,
    description: "Totals only. Who voted for what stays private",
    required: ~w[id message_id multiple closes_at closed_at voters options mine]a,
    properties: %{
      id: uuid(),
      message_id: uuid(description: "The chat message whose body is the question"),
      multiple: boolean(description: "People may pick more than one choice"),
      closes_at: nullable(string(format: :"date-time", description: "When it closes by itself")),
      closed_at: nullable(string(format: :"date-time")),
      voters: non_neg_integer(description: "How many people voted"),
      options: array_of(PollOption),
      mine: array_of(uuid(), description: "The choices the viewer picked")
    }
  }
end
