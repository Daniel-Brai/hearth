defmodule HearthWeb.Schema.PollOption do
  use JSV.Schema

  defschema %{
    title: "PollOption",
    type: :object,
    required: [:id, :label, :votes],
    properties: %{
      id: uuid(),
      label: string(),
      votes: non_neg_integer()
    }
  }
end
