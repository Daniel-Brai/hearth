defmodule HearthWeb.Schema.VoteBody do
  use JSV.Schema

  defschema %{
    title: "VoteBody",
    type: :object,
    required: [:option_ids],
    additionalProperties: false,
    properties: %{
      option_ids:
        array_of(uuid(),
          maxItems: 10,
          description: "Replaces the viewer's earlier vote. Empty takes it back"
        )
    }
  }
end
