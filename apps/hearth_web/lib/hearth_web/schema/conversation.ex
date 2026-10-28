defmodule HearthWeb.Schema.Conversation do
  use JSV.Schema

  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "Conversation",
    type: :object,
    required: [:id, :kind, :name, :member_ids, :members],
    properties: %{
      id: uuid(),
      kind: enum(~w[direct group]),
      name: nullable(string()),
      member_ids: array_of(uuid()),
      members: array_of(UserSummary, description: "Everyone in it, the viewer too")
    }
  }
end
