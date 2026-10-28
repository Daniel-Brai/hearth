defmodule HearthWeb.Schema.Draft do
  use JSV.Schema

  defschema %{
    title: "Draft",
    type: :object,
    required: ~w[community_id kind_id kind title body updated_at]a,
    properties: %{
      community_id: uuid(),
      kind_id: nullable(uuid()),
      kind: nullable(string(description: "The kind's label in the list of drafts")),
      title: nullable(string()),
      body: nullable(string()),
      updated_at: string(format: :"date-time")
    }
  }
end
